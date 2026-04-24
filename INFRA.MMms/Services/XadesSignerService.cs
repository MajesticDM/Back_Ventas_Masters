using CORE.MMms.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Numerics;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Security.Cryptography.Xml;
using System.Xml;

namespace INFRA.MMms.Services
{
    /// <summary>
    /// Phase 2: XAdES-B-BES digital signature for DIAN electronic invoicing.
    ///
    /// Produces a ds:Signature embedded in ext:ExtensionContent with:
    ///   - RSA-SHA256 signature algorithm
    ///   - SHA-256 digest algorithm
    ///   - Exclusive canonicalization (exc-c14n)
    ///   - XAdES QualifyingProperties with SignedProperties
    ///
    /// Three ds:Reference elements per Anexo Técnico v1.9:
    ///   [0] URI=""           — entire invoice document (enveloped-signature + exc-c14n)
    ///   [1] URI="#keyinfo-id" — ds:KeyInfo element
    ///   [2] URI="#props-id"  — xades:SignedProperties (Type=SignedProperties)
    /// </summary>
    public class XadesSignerService : IXadesSignerService
    {
        // ----- XML namespace constants -----
        private const string DsNs      = "http://www.w3.org/2000/09/xmldsig#";
        private const string XadesNs   = "http://uri.etsi.org/01903/v1.3.2#";
        private const string ExcC14N   = "http://www.w3.org/2001/10/xml-exc-c14n#";
        private const string RsaSha256 = "http://www.w3.org/2001/09/xmldsig-more#rsa-sha256";
        private const string Sha256Url = "http://www.w3.org/2001/04/xmlenc#sha256";
        private const string EnvSig    = "http://www.w3.org/2000/09/xmldsig#enveloped-signature";
        private const string SigPropsT = "http://uri.etsi.org/01903#SignedProperties";
        private const string ExtNs     = "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2";

        // SHA-256 of 32 zero bytes — placeholder while we compute real digests
        private static readonly string Placeholder =
            Convert.ToBase64String(new byte[32]);

        private readonly string _p12Path;
        private readonly string _p12Password;

        public XadesSignerService(IConfiguration config)
        {
            _p12Path     = config["Dian:CertificadoRuta"]
                           ?? throw new InvalidOperationException("Dian:CertificadoRuta no configurado.");
            _p12Password = config["Dian:CertificadoClave"]
                           ?? throw new InvalidOperationException("Dian:CertificadoClave no configurado.");
        }

        // ----------------------------------------------------------------
        // Public API
        // ----------------------------------------------------------------
        public string FirmarXml(string xmlSinFirmar)
        {
            using var cert = LoadCertificate();
            var xmlDoc = ParseDoc(xmlSinFirmar);

            // Generate stable IDs for all signature elements
            var uid       = Guid.NewGuid().ToString("N");
            var sigId     = $"xmldsig-{uid}";
            var kiId      = $"{sigId}-keyinfo";
            var spId      = $"{sigId}-signedprops";
            var svId      = $"{sigId}-sigvalue";
            var r0Id      = $"{sigId}-ref0";

            var certDer    = cert.Export(X509ContentType.Cert);
            var certB64    = Convert.ToBase64String(certDer);
            var certDigest = Convert.ToBase64String(SHA256.HashData(certDer));
            var sigTime    = DateTime.UtcNow;

            // 1. Build the complete signature structure (placeholder digests, empty SignatureValue)
            //    and embed it in the document so that canonical forms include the correct namespace context.
            var signedPropsXml = BuildSignedPropsXml(spId, sigId, sigTime, certDigest, cert);
            var placeholderSig = BuildSignatureXml(
                sigId, r0Id, kiId, certB64, svId, "",
                spId, signedPropsXml,
                Placeholder, Placeholder, Placeholder);

            var nsm = Nsm(xmlDoc);
            var extContent = xmlDoc.SelectSingleNode("//ext:ExtensionContent", nsm)
                             ?? throw new InvalidOperationException("ext:ExtensionContent not found in XML.");
            extContent.AppendChild(xmlDoc.ImportNode(ParseDoc(placeholderSig).DocumentElement!, true));

            // 2. Compute actual digests from within the assembled document
            //    so that namespace context (ancestors) is correct for exc-c14n.
            var d0 = DocDigest(xmlDoc, sigId);
            var dk = ElemDigest(xmlDoc, $"//ds:KeyInfo[@Id='{kiId}']",                    nsm);
            var ds = ElemDigest(xmlDoc, $"//xades:SignedProperties[@Id='{spId}']",        nsm);

            // 3. Patch DigestValue elements in the document
            SetText(xmlDoc, $"//ds:Reference[@Id='{r0Id}']/ds:DigestValue",                nsm, d0);
            SetText(xmlDoc, $"//ds:Reference[@URI='#{kiId}']/ds:DigestValue",              nsm, dk);
            SetText(xmlDoc, $"//ds:Reference[@URI='#{spId}']/ds:DigestValue",              nsm, ds);

            // 4. Canonicalize ds:SignedInfo in document context (preserves inherited namespaces)
            var signedInfoElem = Elem(xmlDoc, $"//ds:Signature[@Id='{sigId}']/ds:SignedInfo", nsm);
            var canonical      = C14NNodeList(signedInfoElem.SelectNodes("descendant-or-self::node()")!);

            // 5. Sign with RSA-SHA256
            using var rsa   = cert.GetRSAPrivateKey()
                              ?? throw new InvalidOperationException("No se pudo obtener la clave privada RSA del certificado.");
            var sigBytes    = rsa.SignData(canonical, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

            // 6. Write SignatureValue
            Elem(xmlDoc, $"//ds:SignatureValue[@Id='{svId}']", nsm).InnerText =
                Convert.ToBase64String(sigBytes);

            return xmlDoc.OuterXml;
        }

        public bool ValidarFirma(string xmlFirmado)
        {
            try
            {
                var xmlDoc = ParseDoc(xmlFirmado);
                var nsm    = Nsm(xmlDoc);
                var sigEl  = xmlDoc.SelectSingleNode("//ext:ExtensionContent/ds:Signature", nsm) as XmlElement;
                if (sigEl == null) return false;

                var signed = new XadesSignedXml(xmlDoc);
                signed.LoadXml(sigEl);
                return signed.CheckSignature();
            }
            catch
            {
                return false;
            }
        }

        // ----------------------------------------------------------------
        // XML builders
        // ----------------------------------------------------------------
        private static string BuildSignedPropsXml(
            string spId, string sigId, DateTime sigTime,
            string certDigest, X509Certificate2 cert)
        {
            return $"""
                <xades:SignedProperties Id="{spId}" xmlns:xades="{XadesNs}" xmlns:ds="{DsNs}">
                  <xades:SignedSignatureProperties>
                    <xades:SigningTime>{sigTime:yyyy-MM-ddTHH:mm:ss.fffZ}</xades:SigningTime>
                    <xades:SigningCertificate>
                      <xades:Cert>
                        <xades:CertDigest>
                          <ds:DigestMethod Algorithm="{Sha256Url}"/>
                          <ds:DigestValue>{certDigest}</ds:DigestValue>
                        </xades:CertDigest>
                        <xades:IssuerSerial>
                          <ds:X509IssuerName>{EscXml(cert.IssuerName.Name ?? "")}</ds:X509IssuerName>
                          <ds:X509SerialNumber>{DecSerial(cert.SerialNumber ?? "0")}</ds:X509SerialNumber>
                        </xades:IssuerSerial>
                      </xades:Cert>
                    </xades:SigningCertificate>
                  </xades:SignedSignatureProperties>
                </xades:SignedProperties>
                """;
        }

        private static string BuildSignatureXml(
            string sigId, string r0Id, string kiId, string certB64,
            string svId,  string svValue,
            string spId,  string signedPropsXml,
            string d0, string dk, string ds)
        {
            return $"""
                <ds:Signature Id="{sigId}" xmlns:ds="{DsNs}">
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="{ExcC14N}"/>
                    <ds:SignatureMethod Algorithm="{RsaSha256}"/>
                    <ds:Reference Id="{r0Id}" URI="">
                      <ds:Transforms>
                        <ds:Transform Algorithm="{EnvSig}"/>
                        <ds:Transform Algorithm="{ExcC14N}"/>
                      </ds:Transforms>
                      <ds:DigestMethod Algorithm="{Sha256Url}"/>
                      <ds:DigestValue>{d0}</ds:DigestValue>
                    </ds:Reference>
                    <ds:Reference URI="#{kiId}">
                      <ds:Transforms>
                        <ds:Transform Algorithm="{ExcC14N}"/>
                      </ds:Transforms>
                      <ds:DigestMethod Algorithm="{Sha256Url}"/>
                      <ds:DigestValue>{dk}</ds:DigestValue>
                    </ds:Reference>
                    <ds:Reference Type="{SigPropsT}" URI="#{spId}">
                      <ds:Transforms>
                        <ds:Transform Algorithm="{ExcC14N}"/>
                      </ds:Transforms>
                      <ds:DigestMethod Algorithm="{Sha256Url}"/>
                      <ds:DigestValue>{ds}</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
                  <ds:SignatureValue Id="{svId}">{svValue}</ds:SignatureValue>
                  <ds:KeyInfo Id="{kiId}">
                    <ds:X509Data>
                      <ds:X509Certificate>{certB64}</ds:X509Certificate>
                    </ds:X509Data>
                  </ds:KeyInfo>
                  <ds:Object Id="{sigId}-object0">
                    <xades:QualifyingProperties xmlns:xades="{XadesNs}" Target="#{sigId}">
                      {signedPropsXml}
                    </xades:QualifyingProperties>
                  </ds:Object>
                </ds:Signature>
                """;
        }

        // ----------------------------------------------------------------
        // Digest helpers
        // ----------------------------------------------------------------

        // Computes exc-c14n digest of the document EXCLUDING the ds:Signature element
        // (equivalent to applying the enveloped-signature transform).
        private static string DocDigest(XmlDocument doc, string sigId)
        {
            var clone = (XmlDocument)doc.CloneNode(true);
            var nsm2  = Nsm(clone);
            var sig   = clone.SelectSingleNode($"//ds:Signature[@Id='{sigId}']", nsm2);
            sig?.ParentNode?.RemoveChild(sig);

            var t = new XmlDsigExcC14NTransform();
            t.LoadInput(clone);
            return B64Digest((Stream)t.GetOutput(typeof(Stream)));
        }

        // Computes exc-c14n digest of a named element found by XPath, in document context.
        private static string ElemDigest(XmlDocument doc, string xpath, XmlNamespaceManager nsm)
        {
            var elem  = Elem(doc, xpath, nsm);
            var bytes = C14NNodeList(elem.SelectNodes("descendant-or-self::node()")!);
            return Convert.ToBase64String(SHA256.HashData(bytes));
        }

        // Exclusive canonicalization of an XmlNodeList (preserves ancestor namespace context).
        private static byte[] C14NNodeList(XmlNodeList nodeList)
        {
            var t = new XmlDsigExcC14NTransform();
            t.LoadInput(nodeList);
            return ReadStream((Stream)t.GetOutput(typeof(Stream)));
        }

        private static string B64Digest(Stream stream)
        {
            var bytes = ReadStream(stream);
            return Convert.ToBase64String(SHA256.HashData(bytes));
        }

        private static byte[] ReadStream(Stream stream)
        {
            using var ms = new MemoryStream();
            stream.CopyTo(ms);
            return ms.ToArray();
        }

        // ----------------------------------------------------------------
        // DOM helpers
        // ----------------------------------------------------------------
        private static XmlNamespaceManager Nsm(XmlDocument doc)
        {
            var nsm = new XmlNamespaceManager(doc.NameTable);
            nsm.AddNamespace("ds",    DsNs);
            nsm.AddNamespace("ext",   ExtNs);
            nsm.AddNamespace("xades", XadesNs);
            return nsm;
        }

        private static XmlElement Elem(XmlDocument doc, string xpath, XmlNamespaceManager nsm)
            => doc.SelectSingleNode(xpath, nsm) as XmlElement
               ?? throw new InvalidOperationException($"Element not found: {xpath}");

        private static void SetText(XmlDocument doc, string xpath, XmlNamespaceManager nsm, string value)
            => Elem(doc, xpath, nsm).InnerText = value;

        private static XmlDocument ParseDoc(string xml)
        {
            var doc = new XmlDocument { PreserveWhitespace = true };
            doc.LoadXml(xml);
            return doc;
        }

        // ----------------------------------------------------------------
        // Certificate loading
        // ----------------------------------------------------------------
        private X509Certificate2 LoadCertificate()
        {
            if (!File.Exists(_p12Path))
                throw new FileNotFoundException(
                    $"Certificado DIAN no encontrado en: {_p12Path}");

            return new X509Certificate2(
                _p12Path, _p12Password,
                X509KeyStorageFlags.Exportable | X509KeyStorageFlags.MachineKeySet);
        }

        // ----------------------------------------------------------------
        // Utility
        // ----------------------------------------------------------------
        private static string EscXml(string s) => s
            .Replace("&", "&amp;").Replace("<", "&lt;")
            .Replace(">", "&gt;").Replace("\"", "&quot;");

        private static string DecSerial(string hex)
        {
            if (string.IsNullOrEmpty(hex)) return "0";
            if (hex.Length % 2 != 0) hex = "0" + hex;
            var bytes = Convert.FromHexString(hex);
            return new BigInteger(bytes, isUnsigned: true, isBigEndian: true).ToString();
        }

        // ----------------------------------------------------------------
        // SignedXml subclass: resolves IDs inside ds:Object DataObjects
        // (needed for xades:SignedProperties and ds:KeyInfo references).
        // ----------------------------------------------------------------
        private sealed class XadesSignedXml : SignedXml
        {
            public XadesSignedXml(XmlDocument doc) : base(doc) { }

            public override XmlElement? GetIdElement(XmlDocument doc, string idValue)
            {
                var el = base.GetIdElement(doc, idValue);
                if (el != null) return el;

                foreach (DataObject obj in Signature.ObjectList)
                    foreach (XmlNode node in obj.Data)
                        if (node is XmlElement e)
                        {
                            var found = FindById(e, idValue);
                            if (found != null) return found;
                        }

                return null;
            }

            private static XmlElement? FindById(XmlElement root, string id)
            {
                if (root.GetAttribute("Id") == id) return root;
                foreach (XmlNode child in root.ChildNodes)
                    if (child is XmlElement ce)
                    {
                        var found = FindById(ce, id);
                        if (found != null) return found;
                    }
                return null;
            }
        }
    }
}
