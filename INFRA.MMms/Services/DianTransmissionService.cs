using CORE.MMms.DTOs;
using CORE.MMms.Interfaces;
using Microsoft.Extensions.Configuration;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Xml.Linq;

namespace INFRA.MMms.Services
{
    /// <summary>
    /// Phase 3: transmits the signed UBL 2.1 XML to the DIAN SOAP web service.
    ///
    /// Flow:
    ///   1. Fetch signed XML from FACTURAS.XML_DIAN via SP_DIAN_OBTENER_XML.
    ///   2. Package XML inside a ZIP (filename = ZipKey, e.g. SETT000001).
    ///   3. Build a SOAP 1.1 envelope with WS-Security UsernameToken.
    ///      Password = BASE64( SHA-384( SoftwareId + SoftwarePin + ZipKey ) )
    ///   4. POST to SendBillAsync — DIAN returns an XmlDocumentKey (TrackId).
    ///   5. Persist TrackId; poll GetStatus up to MaxPolls times.
    ///   6. Map DIAN status → ESTADO_DIAN and persist via SP_DIAN_ACTUALIZAR_ESTADO.
    ///
    /// Contingency: any network error sets ESTADO_DIAN = 'CONTINGENCIA'.
    /// </summary>
    public class DianTransmissionService : IDianTransmissionService
    {
        // ---- XML namespaces ----
        private const string SoapNs  = "http://schemas.xmlsoap.org/soap/envelope/";
        private const string DianNs  = "http://wcf.dian.colombia";
        private const string WsseNs  = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd";
        private const string WsuNs   = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd";
        private const string PwdType = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText";
        private const string B64Type = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary";

        // ---- DIAN endpoints ----
        private const string UrlHab  = "https://vpfe-hab.dian.gov.co/WcfDianCustomerServices.svc";
        private const string UrlProd = "https://vpfe.dian.gov.co/WcfDianCustomerServices.svc";

        // ---- Polling ----
        private const int MaxPolls    = 5;
        private const int PollDelayMs = 3_000;

        // ---- Status codes that mean "still processing, keep polling" ----
        private static readonly HashSet<string> ProcessingCodes =
            new(StringComparer.OrdinalIgnoreCase) { "00", "01", "66" };

        private readonly IDian               _repo;
        private readonly IHttpClientFactory  _httpFactory;
        private readonly string              _softwareId;
        private readonly string              _softwarePin;

        public DianTransmissionService(
            IDian repo, IHttpClientFactory httpFactory, IConfiguration config)
        {
            _repo        = repo;
            _httpFactory = httpFactory;
            _softwareId  = config["Dian:SoftwareId"]
                           ?? throw new InvalidOperationException("Dian:SoftwareId no configurado.");
            _softwarePin = config["Dian:SoftwarePin"]
                           ?? throw new InvalidOperationException("Dian:SoftwarePin no configurado.");
        }

        // ----------------------------------------------------------------
        // Public API
        // ----------------------------------------------------------------
        public async Task<DianEnvioResultDto> EnviarFacturaAsync(long idFactura)
        {
            var datos = _repo.GetXmlPendiente(idFactura)
                ?? throw new InvalidOperationException(
                    $"No existe XML firmado para la factura {idFactura}. Ejecute GenerarXml primero.");

            if (string.IsNullOrWhiteSpace(datos.XmlFirmado))
                throw new InvalidOperationException(
                    $"El campo XML_DIAN está vacío para la factura {idFactura}.");

            var endpoint = datos.AmbienteDian == 1 ? UrlProd : UrlHab;
            var zipKey   = datos.ZipKey;                         // e.g. "SETT000001"
            var base64Zip = Convert.ToBase64String(BuildZip(zipKey + ".xml", datos.XmlFirmado));

            try
            {
                // ---- Step 1: SendBillAsync ----
                var sendXml = await PostSoapAsync(
                    endpoint,
                    BuildSendBillEnvelope(zipKey, base64Zip),
                    "http://wcf.dian.colombia/IWcfDianCustomerServices/SendBillAsync");

                var trackId  = ParseElement(sendXml, "XmlDocumentKey");
                var sendCode = ParseElement(sendXml, "StatusCode");
                var sendDesc = ParseElement(sendXml, "StatusDescription");

                if (string.IsNullOrEmpty(trackId))
                {
                    // DIAN rejected immediately (e.g. duplicate, malformed XML)
                    _repo.ActualizarEstado(idFactura, null, "RECHAZADA", null, null, sendDesc);
                    return BuildResult(idFactura, "RECHAZADA", null, sendDesc, null, sendCode, sendDesc);
                }

                // Persist TrackId — state stays PENDIENTE during polling
                _repo.ActualizarTrackId(idFactura, trackId);

                // ---- Step 2: Poll GetStatus ----
                return await PollAsync(idFactura, trackId, endpoint);
            }
            catch (HttpRequestException ex)
            {
                var nota = $"Error de red al contactar DIAN: {ex.Message}";
                _repo.ActualizarEstado(idFactura, null, "CONTINGENCIA", null, null, nota);
                return BuildResult(idFactura, "CONTINGENCIA", null, nota, null, null, null);
            }
            catch (TaskCanceledException ex)
            {
                var nota = $"Tiempo de espera agotado al contactar DIAN: {ex.Message}";
                _repo.ActualizarEstado(idFactura, null, "CONTINGENCIA", null, null, nota);
                return BuildResult(idFactura, "CONTINGENCIA", null, nota, null, null, null);
            }
        }

        public async Task<DianEnvioResultDto> ConsultarEstadoAsync(long idFactura)
        {
            var datos = _repo.GetXmlPendiente(idFactura)
                ?? throw new InvalidOperationException(
                    $"No se encontró la factura {idFactura} o no tiene XML firmado.");

            if (string.IsNullOrEmpty(datos.TrackId))
                throw new InvalidOperationException(
                    $"La factura {idFactura} no tiene TrackId DIAN. Use EnviarFactura primero.");

            var endpoint = datos.AmbienteDian == 1 ? UrlProd : UrlHab;
            return await PollAsync(idFactura, datos.TrackId, endpoint);
        }

        public async Task<DianLoteResultDto> EnviarLoteAsync(long[] ids)
        {
            var tasks   = ids.Select(id => EnviarFacturaAsync(id)).ToArray();
            var results = await Task.WhenAll(tasks);

            return new DianLoteResultDto
            {
                Total         = results.Length,
                Validadas     = results.Count(r => r.EstadoDian == "VALIDADA"),
                Rechazadas    = results.Count(r => r.EstadoDian == "RECHAZADA"),
                Pendientes    = results.Count(r => r.EstadoDian == "PENDIENTE"),
                Contingencias = results.Count(r => r.EstadoDian == "CONTINGENCIA"),
                Detalle       = results.ToList()
            };
        }

        // ----------------------------------------------------------------
        // Polling
        // ----------------------------------------------------------------
        private async Task<DianEnvioResultDto> PollAsync(
            long idFactura, string trackId, string endpoint)
        {
            string code  = string.Empty;
            string desc  = string.Empty;
            string qr    = string.Empty;
            string error = string.Empty;
            bool   valid = false;

            for (int i = 0; i < MaxPolls; i++)
            {
                await Task.Delay(PollDelayMs);

                var statusXml = await PostSoapAsync(
                    endpoint,
                    BuildGetStatusEnvelope(trackId),
                    "http://wcf.dian.colombia/IWcfDianCustomerServices/GetStatus");

                code  = ParseElement(statusXml, "StatusCode");
                desc  = ParseElement(statusXml, "StatusDescription");
                qr    = ParseElement(statusXml, "QRStr");
                error = ParseElement(statusXml, "ErrorMessage");
                valid = ParseElement(statusXml, "IsValid")
                            .Equals("true", StringComparison.OrdinalIgnoreCase);

                if (!ProcessingCodes.Contains(code)) break;
            }

            // Map to ESTADO_DIAN
            var estado = valid                          ? "VALIDADA"
                       : ProcessingCodes.Contains(code) ? "PENDIENTE"
                                                        : "RECHAZADA";

            var qrFinal = estado == "VALIDADA" && !string.IsNullOrEmpty(qr) ? qr : null;
            var notas   = estado != "VALIDADA"
                            ? (string.IsNullOrEmpty(error) ? desc : error)
                            : null;

            _repo.ActualizarEstado(idFactura, null, estado, qrFinal, null,
                string.IsNullOrWhiteSpace(notas) ? null : notas);

            return BuildResult(idFactura, estado, qrFinal, notas, trackId, code, desc);
        }

        // ----------------------------------------------------------------
        // SOAP envelope builders
        // ----------------------------------------------------------------
        private string BuildSendBillEnvelope(string zipKey, string base64Zip)
        {
            var (pwd, nonce, created) = WsSecurityValues(zipKey);
            return Envelope(_softwareId, pwd, nonce, created,
                $"""
                <wcf:SendBillAsync xmlns:wcf="{DianNs}">
                  <wcf:fileName>{X(zipKey)}.zip</wcf:fileName>
                  <wcf:contentFile>{base64Zip}</wcf:contentFile>
                </wcf:SendBillAsync>
                """);
        }

        private string BuildGetStatusEnvelope(string trackId)
        {
            // DIAN uses the trackId as the key for WS-Security on GetStatus
            var (pwd, nonce, created) = WsSecurityValues(trackId);
            return Envelope(_softwareId, pwd, nonce, created,
                $"""
                <wcf:GetStatus xmlns:wcf="{DianNs}">
                  <wcf:trackId>{X(trackId)}</wcf:trackId>
                </wcf:GetStatus>
                """);
        }

        private string Envelope(
            string username, string password, string nonce, string created, string body)
        {
            return $"""
                <?xml version="1.0" encoding="utf-8"?>
                <soap:Envelope
                    xmlns:soap="{SoapNs}"
                    xmlns:wcf="{DianNs}">
                  <soap:Header>
                    <wsse:Security
                        xmlns:wsse="{WsseNs}"
                        xmlns:wsu="{WsuNs}"
                        soap:mustUnderstand="1">
                      <wsse:UsernameToken>
                        <wsse:Username>{X(username)}</wsse:Username>
                        <wsse:Password Type="{PwdType}">{X(password)}</wsse:Password>
                        <wsse:Nonce EncodingType="{B64Type}">{nonce}</wsse:Nonce>
                        <wsu:Created>{created}</wsu:Created>
                      </wsse:UsernameToken>
                    </wsse:Security>
                  </soap:Header>
                  <soap:Body>
                    {body}
                  </soap:Body>
                </soap:Envelope>
                """;
        }

        // ----------------------------------------------------------------
        // WS-Security token
        // Password = BASE64( SHA-384( softwareId + softwarePin + key ) )
        // ----------------------------------------------------------------
        private (string password, string nonce, string created) WsSecurityValues(string key)
        {
            var raw      = _softwareId + _softwarePin + key;
            var hash     = SHA384.HashData(Encoding.UTF8.GetBytes(raw));
            var password = Convert.ToBase64String(hash);
            var nonce    = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
            var created  = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
            return (password, nonce, created);
        }

        // ----------------------------------------------------------------
        // HTTP
        // ----------------------------------------------------------------
        private async Task<string> PostSoapAsync(
            string endpoint, string envelope, string soapAction)
        {
            var client  = _httpFactory.CreateClient("dian");
            var content = new StringContent(envelope, Encoding.UTF8, "text/xml");
            content.Headers.Add("SOAPAction", $"\"{soapAction}\"");

            var response = await client.PostAsync(endpoint, content);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }

        // ----------------------------------------------------------------
        // ZIP packaging
        // ----------------------------------------------------------------
        private static byte[] BuildZip(string fileName, string xmlContent)
        {
            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
            {
                var entry = zip.CreateEntry(fileName, CompressionLevel.Optimal);
                using var writer = entry.Open();
                var bytes = Encoding.UTF8.GetBytes(xmlContent);
                writer.Write(bytes, 0, bytes.Length);
            }
            return ms.ToArray();
        }

        // ----------------------------------------------------------------
        // XML response parsing — navigates by local name to avoid namespace issues
        // ----------------------------------------------------------------
        private static string ParseElement(string soapXml, string localName)
        {
            try
            {
                return XDocument.Parse(soapXml)
                    .Descendants()
                    .FirstOrDefault(e => e.Name.LocalName == localName)
                    ?.Value ?? string.Empty;
            }
            catch { return string.Empty; }
        }

        // ----------------------------------------------------------------
        // Helpers
        // ----------------------------------------------------------------
        private static DianEnvioResultDto BuildResult(
            long idFactura, string estado, string? qr, string? notas,
            string? trackId, string? code, string? desc) => new()
        {
            IdFactura         = idFactura,
            EstadoDian        = estado,
            QrDian            = qr,
            NotasDian         = string.IsNullOrWhiteSpace(notas) ? null : notas,
            TrackId           = trackId,
            DianStatusCode    = code,
            DianStatusMessage = desc
        };

        // XML-escape a value for embedding in a string-built SOAP envelope
        private static string X(string s) => s
            .Replace("&", "&amp;").Replace("<", "&lt;")
            .Replace(">", "&gt;").Replace("\"", "&quot;");
    }
}
