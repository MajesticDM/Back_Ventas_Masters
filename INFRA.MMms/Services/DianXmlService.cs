using CORE.MMms.DTOs;
using CORE.MMms.Interfaces;
using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Xml.Linq;

namespace INFRA.MMms.Services
{
    /// <summary>
    /// Phase 1: Builds UBL 2.1 Invoice XML for DIAN and computes the CUFE (SHA-384).
    /// Phase 2: Signs the XML with XAdES-B-BES using the configured .p12 certificate.
    /// </summary>
    public class DianXmlService : IDianXmlService
    {
        // UBL 2.1 namespaces required by DIAN
        private static readonly XNamespace Ubl = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2";
        private static readonly XNamespace Cac = "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2";
        private static readonly XNamespace Cbc = "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2";
        private static readonly XNamespace Ext = "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2";
        private static readonly XNamespace Ds  = "http://www.w3.org/2000/09/xmldsig#";

        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private readonly IDian _repo;
        private readonly IXadesSignerService _signer;

        public DianXmlService(IDian repo, IXadesSignerService signer)
        {
            _repo   = repo;
            _signer = signer;
        }

        public DianGenerarXmlResultDto GenerarXml(long idFactura)
        {
            var ds = _repo.GetDatosFactura(idFactura);

            if (ds.Tables.Count < 4 || ds.Tables[0].Rows.Count == 0)
                throw new InvalidOperationException(
                    $"No se encontraron datos para la factura {idFactura}.");

            var header   = ds.Tables[0].Rows[0];
            var products = ds.Tables[1];
            var services = ds.Tables[2];
            var taxes    = ds.Tables[3];

            var numeroDian = $"{Str(header["prefijo_dian"])}{header["NUMERO_FACTURA_DIAN"]}";
            var cufe       = CalcularCufe(header);
            var xml        = BuildUblXml(header, products, services, taxes, cufe, numeroDian);

            // Serialize: declaration + newline + document
            var xmlStr = xml.Declaration + Environment.NewLine + xml.ToString(SaveOptions.None);

            // Phase 2: embed XAdES-B-BES signature
            var signedXml = _signer.FirmarXml(xmlStr);

            if (!_signer.ValidarFirma(signedXml))
                throw new InvalidOperationException(
                    $"La validación local de la firma XAdES falló para la factura {idFactura}.");

            // Persist signed XML and CUFE; state remains PENDIENTE until Phase 3 transmits to DIAN
            _repo.ActualizarEstado(idFactura, cufe, null, null, signedXml, null);

            return new DianGenerarXmlResultDto
            {
                IdFactura         = idFactura,
                Cufe              = cufe,
                Xml               = signedXml,
                EstadoDian        = "PENDIENTE",
                NumeroFacturaDian = numeroDian
            };
        }

        // ----------------------------------------------------------------
        // CUFE — SHA-384 per DIAN spec
        // Formula: NumFac+FecFac+HorFac+ValFac+CodImp1+ValImp1+ValImp2+ValImp3
        //          +ValTot+NitOFE+TipDocAdq+NumDocAdq+ClTec+TipoAmb
        // ----------------------------------------------------------------
        private static string CalcularCufe(DataRow h)
        {
            var numFac    = $"{Str(h["prefijo_dian"])}{h["NUMERO_FACTURA_DIAN"]}";
            var fecFac    = Str(h["fecha_dian"]);                   // yyyyMMdd
            var horFac    = Str(h["hora_dian"]);                    // HH:mm:ss-05:00
            var valFac    = Num2(h["subtotal"]);
            var valImp1   = Num2(h["total_iva"]);
            var valTot    = Num2(h["total"]);
            var nitOfe    = Str(h["emisor_nit"]);
            var tipDocAdq = Str(h["adquirente_tipo_documento"]);
            var numDocAdq = Str(h["adquirente_identificacion"]);
            var clTec     = Str(h["clave_tecnica"]);
            var tipoAmb   = Str(h["ambiente_dian"]);

            // CodImp2="04" (INC) and CodImp3="03" (ICA) are always present in the
            // concatenation even when their values are zero — required by Anexo Técnico v1.9.
            var raw = $"{numFac}{fecFac}{horFac}{valFac}01{valImp1}040.00030.00{valTot}" +
                      $"{nitOfe}{tipDocAdq}{numDocAdq}{clTec}{tipoAmb}";

            var hash = SHA384.HashData(Encoding.UTF8.GetBytes(raw));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        // ----------------------------------------------------------------
        // UBL 2.1 Invoice document
        // ----------------------------------------------------------------
        private static XDocument BuildUblXml(
            DataRow header, DataTable products, DataTable services,
            DataTable taxes, string cufe, string numeroDian)
        {
            var ambiente  = Str(header["ambiente_dian"]);
            var lineCount = products.Rows.Count + services.Rows.Count;
            var issueDate = ParseFechaDian(Str(header["fecha_dian"])); // yyyy-MM-dd

            var doc = new XDocument(
                new XDeclaration("1.0", "UTF-8", null),
                new XElement(Ubl + "Invoice",
                    new XAttribute(XNamespace.Xmlns + "cac", Cac),
                    new XAttribute(XNamespace.Xmlns + "cbc", Cbc),
                    new XAttribute(XNamespace.Xmlns + "ext", Ext),
                    new XAttribute(XNamespace.Xmlns + "ds",  Ds),

                    // Placeholder for XAdES-B-BES signature (Phase 2)
                    new XElement(Ext + "UBLExtensions",
                        new XElement(Ext + "UBLExtension",
                            new XElement(Ext + "ExtensionContent")
                        )
                    ),

                    new XElement(Cbc + "UBLVersionID", "UBL 2.1"),
                    new XElement(Cbc + "CustomizationID", "10"),
                    new XElement(Cbc + "ProfileID", "DIAN 2.1"),
                    new XElement(Cbc + "ProfileExecutionID", ambiente),
                    new XElement(Cbc + "ID", numeroDian),
                    new XElement(Cbc + "UUID",
                        new XAttribute("schemeID", ambiente),
                        new XAttribute("schemeName", "CUFE-SHA384"),
                        cufe
                    ),
                    new XElement(Cbc + "IssueDate", issueDate),
                    new XElement(Cbc + "IssueTime", Str(header["hora_dian"])),
                    new XElement(Cbc + "InvoiceTypeCode",
                        new XAttribute("listAgencyID", "195"),
                        new XAttribute("listSchemeURI",
                            "http://www.dian.gov.co/contratos/facturaelectronica/v1/InvoiceType"),
                        "01"
                    ),
                    new XElement(Cbc + "Note", $"CUFE: {cufe}"),
                    new XElement(Cbc + "DocumentCurrencyCode",
                        new XAttribute("listID", "ISO 4217 Alpha"),
                        new XAttribute("listAgencyID", "6"),
                        new XAttribute("listAgencyName",
                            "United Nations Economic Commission for Europe"),
                        "COP"
                    ),
                    new XElement(Cbc + "LineCountNumeric", lineCount),

                    // InvoicePeriod: required when invoice contains services; harmless for goods-only
                    new XElement(Cac + "InvoicePeriod",
                        new XElement(Cbc + "StartDate", issueDate),
                        new XElement(Cbc + "EndDate",   issueDate)
                    ),

                    // AdditionalDocumentReference links the invoice to its DIAN authorization resolution
                    // (Anexo Técnico v1.9 — DocumentTypeCode "09")
                    BuildAdditionalDocumentReference(header),

                    BuildSupplierParty(header),
                    BuildCustomerParty(header),
                    BuildPaymentMeans(header, issueDate, numeroDian),
                    BuildPrepaidPaymentIfNeeded(header, issueDate),
                    BuildTaxTotal(taxes, header),
                    BuildLegalMonetaryTotal(header),
                    BuildProductLines(products),
                    BuildServiceLines(services, products.Rows.Count)
                )
            );

            return doc;
        }

        // ----------------------------------------------------------------
        // AdditionalDocumentReference — DIAN authorization resolution
        // DocumentTypeCode "09" = Authorization resolution (Anexo Técnico v1.9)
        // ----------------------------------------------------------------
        private static XElement BuildAdditionalDocumentReference(DataRow h)
        {
            return new XElement(Cac + "AdditionalDocumentReference",
                new XElement(Cbc + "ID", Str(h["NUMERO_RESOLUCION"])),
                new XElement(Cbc + "IssueDate", DateStr(h["fecha_resolucion"])),
                new XElement(Cbc + "DocumentType", "RESOLUCION"),
                new XElement(Cbc + "DocumentTypeCode", "09"),
                new XElement(Cac + "Attachment",
                    new XElement(Cac + "ExternalReference",
                        new XElement(Cbc + "Description",
                            $"Resolución DIAN {Str(h["NUMERO_RESOLUCION"])} " +
                            $"del {DateStr(h["fecha_resolucion"])}. " +
                            $"Rango {h["rango_inicio"]} al {h["rango_fin"]}. " +
                            $"Vigencia {DateStr(h["fecha_inicio_vigencia"])} al {DateStr(h["fecha_fin_vigencia"])}."
                        )
                    )
                )
            );
        }

        // ----------------------------------------------------------------
        // Accounting Supplier Party (emisor)
        // ----------------------------------------------------------------
        private static XElement BuildSupplierParty(DataRow h)
        {
            return new XElement(Cac + "AccountingSupplierParty",
                new XElement(Cbc + "AdditionalAccountID", "1"),
                new XElement(Cac + "Party",
                    new XElement(Cac + "PartyName",
                        new XElement(Cbc + "Name", Str(h["emisor_nombre_comercial"]))
                    ),
                    BuildPhysicalLocation(h["emisor_municipio"], h["emisor_departamento"],
                                          h["emisor_codigo_postal"], h["emisor_direccion"]),
                    new XElement(Cac + "PartyTaxScheme",
                        new XElement(Cbc + "RegistrationName", Str(h["emisor_razon_social"])),
                        new XElement(Cbc + "CompanyID",
                            new XAttribute("schemeAgencyID", "195"),
                            new XAttribute("schemeAgencyName",
                                "CO, DIAN (Direccion de Impuestos y Aduanas Nacionales)"),
                            new XAttribute("schemeID",   Str(h["emisor_digito_verificacion"])),
                            new XAttribute("schemeName", Str(h["emisor_tipo_documento"])),
                            Str(h["emisor_nit"])
                        ),
                        new XElement(Cbc + "TaxLevelCode",
                            new XAttribute("listName", "48"),
                            Str(h["emisor_responsabilidad"])
                        ),
                        BuildRegistrationAddress(h["emisor_municipio"], h["emisor_departamento"],
                                                  h["emisor_codigo_postal"], h["emisor_direccion"]),
                        new XElement(Cac + "TaxScheme",
                            new XElement(Cbc + "ID", "01"),
                            new XElement(Cbc + "Name", "IVA")
                        )
                    ),
                    new XElement(Cac + "PartyLegalEntity",
                        new XElement(Cbc + "RegistrationName", Str(h["emisor_razon_social"])),
                        new XElement(Cbc + "CompanyID",
                            new XAttribute("schemeAgencyID", "195"),
                            new XAttribute("schemeAgencyName",
                                "CO, DIAN (Direccion de Impuestos y Aduanas Nacionales)"),
                            new XAttribute("schemeID",   Str(h["emisor_digito_verificacion"])),
                            new XAttribute("schemeName", Str(h["emisor_tipo_documento"])),
                            Str(h["emisor_nit"])
                        ),
                        new XElement(Cac + "CorporateRegistrationScheme",
                            new XElement(Cbc + "ID", Str(h["prefijo_dian"]))
                        )
                    ),
                    new XElement(Cac + "Contact",
                        new XElement(Cbc + "Telephone", Str(h["emisor_telefono"])),
                        new XElement(Cbc + "ElectronicMail", Str(h["emisor_email"]))
                    )
                )
            );
        }

        // ----------------------------------------------------------------
        // Accounting Customer Party (adquirente)
        // ----------------------------------------------------------------
        private static XElement BuildCustomerParty(DataRow h)
        {
            return new XElement(Cac + "AccountingCustomerParty",
                new XElement(Cbc + "AdditionalAccountID", "1"),
                new XElement(Cac + "Party",
                    new XElement(Cac + "PartyName",
                        new XElement(Cbc + "Name", Str(h["adquirente_nombre"]))
                    ),
                    BuildPhysicalLocation(h["adquirente_municipio"], null,
                                          h["adquirente_codigo_postal"], h["adquirente_direccion"]),
                    new XElement(Cac + "PartyTaxScheme",
                        new XElement(Cbc + "RegistrationName", Str(h["adquirente_nombre"])),
                        new XElement(Cbc + "CompanyID",
                            new XAttribute("schemeAgencyID", "195"),
                            new XAttribute("schemeAgencyName",
                                "CO, DIAN (Direccion de Impuestos y Aduanas Nacionales)"),
                            // schemeID = dígito de verificación (0 for natural persons / CC / CE)
                            new XAttribute("schemeID",   Str(h["adquirente_digito_verificacion"])),
                            new XAttribute("schemeName", Str(h["adquirente_tipo_documento"])),
                            Str(h["adquirente_identificacion"])
                        ),
                        new XElement(Cbc + "TaxLevelCode",
                            new XAttribute("listName", "48"),
                            Str(h["adquirente_responsabilidad"])
                        ),
                        BuildRegistrationAddress(h["adquirente_municipio"], null,
                                                  h["adquirente_codigo_postal"], h["adquirente_direccion"]),
                        new XElement(Cac + "TaxScheme",
                            new XElement(Cbc + "ID", "ZZ"),
                            new XElement(Cbc + "Name", "No aplica")
                        )
                    ),
                    new XElement(Cac + "PartyLegalEntity",
                        new XElement(Cbc + "RegistrationName", Str(h["adquirente_nombre"])),
                        new XElement(Cbc + "CompanyID",
                            new XAttribute("schemeAgencyID", "195"),
                            new XAttribute("schemeAgencyName",
                                "CO, DIAN (Direccion de Impuestos y Aduanas Nacionales)"),
                            new XAttribute("schemeID",   Str(h["adquirente_digito_verificacion"])),
                            new XAttribute("schemeName", Str(h["adquirente_tipo_documento"])),
                            Str(h["adquirente_identificacion"])
                        )
                    ),
                    new XElement(Cac + "Contact",
                        new XElement(Cbc + "Telephone", Str(h["adquirente_telefono"])),
                        new XElement(Cbc + "ElectronicMail", Str(h["adquirente_email"]))
                    )
                )
            );
        }

        // ----------------------------------------------------------------
        // Payment means
        // ----------------------------------------------------------------
        private static XElement BuildPaymentMeans(DataRow h, string issueDate, string numeroDian)
        {
            var isCredit  = Str(h["tipo_pago_dian"]) == "Crédito";
            var dueDate   = DateStr(h["fecha_vencimiento_dian"]);

            return new XElement(Cac + "PaymentMeans",
                new XElement(Cbc + "ID", isCredit ? "2" : "1"),
                new XElement(Cbc + "PaymentMeansCode",
                    new XAttribute("listAgencyID", "6"),
                    new XAttribute("listAgencyName",
                        "United Nations Economic Commission for Europe"),
                    Str(h["codigo_medio_pago_dian"])
                ),
                new XElement(Cbc + "PaymentDueDate", dueDate),
                new XElement(Cbc + "PaymentID", numeroDian)
            );
        }

        // ----------------------------------------------------------------
        // PrepaidPayment — only emitted when PAGO_INICIAL > 0
        // Covers both partial credit payments and saldo-a-favor redemptions
        // ----------------------------------------------------------------
        private static XElement? BuildPrepaidPaymentIfNeeded(DataRow h, string issueDate)
        {
            var prepago = h["prepago"] == DBNull.Value ? 0m : Convert.ToDecimal(h["prepago"], Inv);
            if (prepago <= 0m) return null;

            return new XElement(Cac + "PrepaidPayment",
                new XElement(Cbc + "ID", "Abono previo"),
                new XElement(Cbc + "PaidAmount",
                    new XAttribute("currencyID", "COP"),
                    prepago.ToString("F2", Inv)
                ),
                new XElement(Cbc + "ReceivedDate", issueDate)
            );
        }

        // ----------------------------------------------------------------
        // TaxTotal (for the whole invoice, from tables[3])
        // ----------------------------------------------------------------
        private static XElement BuildTaxTotal(DataTable taxes, DataRow h)
        {
            var subtotals = taxes.AsEnumerable().Select(t =>
                new XElement(Cac + "TaxSubtotal",
                    new XElement(Cbc + "TaxableAmount",
                        new XAttribute("currencyID", "COP"),
                        Num2(t["base_gravable"])
                    ),
                    new XElement(Cbc + "TaxAmount",
                        new XAttribute("currencyID", "COP"),
                        Num2(t["valor_impuesto"])
                    ),
                    new XElement(Cac + "TaxCategory",
                        new XElement(Cbc + "Percent", Num2(t["porcentaje"])),
                        new XElement(Cac + "TaxScheme",
                            new XElement(Cbc + "ID",   Str(t["codigo_tributo"])),
                            new XElement(Cbc + "Name", Str(t["nombre_tributo"]))
                        )
                    )
                )
            );

            return new XElement(Cac + "TaxTotal",
                new XElement(Cbc + "TaxAmount",
                    new XAttribute("currencyID", "COP"),
                    Num2(h["total_iva"])
                ),
                subtotals
            );
        }

        // ----------------------------------------------------------------
        // LegalMonetaryTotal
        // PayableAmount = total - prepago (reflects what is still owed)
        // ----------------------------------------------------------------
        private static XElement BuildLegalMonetaryTotal(DataRow h)
        {
            var total   = Convert.ToDecimal(h["total"],   Inv);
            var prepago = h["prepago"] == DBNull.Value ? 0m : Convert.ToDecimal(h["prepago"], Inv);
            var payable = total - prepago;

            var elements = new List<XElement>
            {
                new XElement(Cbc + "LineExtensionAmount",
                    new XAttribute("currencyID", "COP"), Num2(h["subtotal"])),
                new XElement(Cbc + "TaxExclusiveAmount",
                    new XAttribute("currencyID", "COP"), Num2(h["subtotal"])),
                new XElement(Cbc + "TaxInclusiveAmount",
                    new XAttribute("currencyID", "COP"), total.ToString("F2", Inv)),
                new XElement(Cbc + "ChargeTotalAmount",
                    new XAttribute("currencyID", "COP"), "0.00"),
            };

            if (prepago > 0m)
                elements.Add(new XElement(Cbc + "PrepaidAmount",
                    new XAttribute("currencyID", "COP"), prepago.ToString("F2", Inv)));

            elements.Add(new XElement(Cbc + "PayableAmount",
                new XAttribute("currencyID", "COP"), payable.ToString("F2", Inv)));

            return new XElement(Cac + "LegalMonetaryTotal", elements);
        }

        // ----------------------------------------------------------------
        // Invoice lines — products (tables[1])
        // ----------------------------------------------------------------
        private static IEnumerable<XElement> BuildProductLines(DataTable products)
        {
            return products.AsEnumerable().Select(p => BuildInvoiceLine(
                lineId:       Str(p["numero_linea"]),
                quantity:     Str(p["cantidad"]),
                unitCode:     Str(p["unidad_medida"]),
                subtotal:     Num2(p["subtotal_linea"]),
                ivaAmount:    Num2(p["valor_iva_linea"]),
                ivaPct:       Num2(p["porcentaje_iva"]),
                codigoTrib:   Str(p["codigo_tributo"]),
                nombreTrib:   Str(p["nombre_tributo"]),
                descripcion:  Str(p["descripcion"]),
                codigoVend:   Str(p["codigo_vendedor"]),
                unspsc:       Str(p["codigo_unspsc"]),
                precioUnit:   Num2(p["precio_unitario"])
            ));
        }

        // ----------------------------------------------------------------
        // Invoice lines — services (tables[2])
        // ----------------------------------------------------------------
        private static IEnumerable<XElement> BuildServiceLines(DataTable services, int productCount)
        {
            return services.AsEnumerable().Select((s, i) => BuildInvoiceLine(
                lineId:       (productCount + i + 1).ToString(),
                quantity:     Str(s["cantidad"]),
                unitCode:     Str(s["unidad_medida"]),
                subtotal:     Num2(s["subtotal_linea"]),
                ivaAmount:    Num2(s["valor_iva_linea"]),
                ivaPct:       Num2(s["porcentaje_iva"]),
                codigoTrib:   Str(s["codigo_tributo"]),
                nombreTrib:   Str(s["nombre_tributo"]),
                descripcion:  Str(s["descripcion"]),
                codigoVend:   $"SVC-{productCount + i + 1:D4}",
                unspsc:       Str(s["codigo_unspsc"]),
                precioUnit:   Num2(s["precio_unitario"])
            ));
        }

        private static XElement BuildInvoiceLine(
            string lineId, string quantity, string unitCode,
            string subtotal, string ivaAmount, string ivaPct,
            string codigoTrib, string nombreTrib,
            string descripcion, string codigoVend, string unspsc, string precioUnit)
        {
            return new XElement(Cac + "InvoiceLine",
                new XElement(Cbc + "ID", lineId),
                new XElement(Cbc + "InvoicedQuantity",
                    new XAttribute("unitCode", unitCode),
                    quantity
                ),
                new XElement(Cbc + "LineExtensionAmount",
                    new XAttribute("currencyID", "COP"),
                    subtotal
                ),
                new XElement(Cac + "TaxTotal",
                    new XElement(Cbc + "TaxAmount",
                        new XAttribute("currencyID", "COP"),
                        ivaAmount
                    ),
                    new XElement(Cac + "TaxSubtotal",
                        new XElement(Cbc + "TaxableAmount",
                            new XAttribute("currencyID", "COP"),
                            subtotal
                        ),
                        new XElement(Cbc + "TaxAmount",
                            new XAttribute("currencyID", "COP"),
                            ivaAmount
                        ),
                        new XElement(Cac + "TaxCategory",
                            new XElement(Cbc + "Percent", ivaPct),
                            new XElement(Cac + "TaxScheme",
                                new XElement(Cbc + "ID",   codigoTrib),
                                new XElement(Cbc + "Name", nombreTrib)
                            )
                        )
                    )
                ),
                new XElement(Cac + "Item",
                    new XElement(Cbc + "Description", descripcion),
                    new XElement(Cac + "SellersItemIdentification",
                        new XElement(Cbc + "ID", codigoVend)
                    ),
                    new XElement(Cac + "StandardItemIdentification",
                        new XElement(Cbc + "ID",
                            new XAttribute("schemeID",       "001"),
                            new XAttribute("schemeName",     "UNSPSC"),
                            new XAttribute("schemeAgencyID", "113"),
                            new XAttribute("schemeAgencyName", "UN/CEFACT"),
                            unspsc
                        )
                    )
                ),
                new XElement(Cac + "Price",
                    new XElement(Cbc + "PriceAmount",
                        new XAttribute("currencyID", "COP"),
                        precioUnit
                    ),
                    new XElement(Cbc + "BaseQuantity",
                        new XAttribute("unitCode", unitCode),
                        "1"
                    )
                )
            );
        }

        // ----------------------------------------------------------------
        // Address helpers
        // ----------------------------------------------------------------
        private static XElement BuildPhysicalLocation(
            object municipio, object? departamento, object codigoPostal, object direccion)
        {
            return new XElement(Cac + "PhysicalLocation",
                BuildAddressFields(municipio, departamento, codigoPostal, direccion));
        }

        private static XElement BuildRegistrationAddress(
            object municipio, object? departamento, object codigoPostal, object direccion)
        {
            return new XElement(Cac + "RegistrationAddress",
                BuildAddressFields(municipio, departamento, codigoPostal, direccion));
        }

        private static XElement BuildAddressFields(
            object municipio, object? departamento, object codigoPostal, object direccion)
        {
            var elements = new List<object>
            {
                new XElement(Cbc + "ID", Str(municipio)),
                new XElement(Cbc + "PostalZone", Str(codigoPostal)),
            };

            if (departamento != null && departamento != DBNull.Value)
                elements.Add(new XElement(Cbc + "CountrySubentityCode", Str(departamento)));

            elements.Add(new XElement(Cac + "AddressLine",
                new XElement(Cbc + "Line", Str(direccion))));
            elements.Add(new XElement(Cac + "Country",
                new XElement(Cbc + "IdentificationCode", "CO"),
                new XElement(Cbc + "Name",
                    new XAttribute("languageID", "es"),
                    "Colombia")
            ));

            return new XElement(Cac + "Address", elements.ToArray());
        }

        // ----------------------------------------------------------------
        // Utility helpers
        // ----------------------------------------------------------------
        private static string Str(object? val)
            => val == null || val == DBNull.Value ? string.Empty : val.ToString()!;

        private static string Num2(object? val)
        {
            if (val == null || val == DBNull.Value) return "0.00";
            return Convert.ToDecimal(val, Inv).ToString("F2", Inv);
        }

        // fecha_dian format is yyyyMMdd from FORMAT() in SQL
        private static string ParseFechaDian(string fechaDian)
        {
            if (fechaDian.Length == 8)
                return $"{fechaDian[..4]}-{fechaDian[4..6]}-{fechaDian[6..8]}";
            return fechaDian;
        }

        private static string DateStr(object? val)
        {
            if (val == null || val == DBNull.Value) return DateTime.Today.ToString("yyyy-MM-dd");
            if (val is DateTime dt) return dt.ToString("yyyy-MM-dd");
            if (DateTime.TryParse(val.ToString(), out var parsed))
                return parsed.ToString("yyyy-MM-dd");
            return val.ToString()!;
        }
    }
}
