namespace CORE.MMms.Interfaces
{
    public interface IXadesSignerService
    {
        /// <summary>
        /// Signs the given UBL 2.1 XML with XAdES-B-BES using the configured .p12 certificate.
        /// Embeds the ds:Signature inside ext:ExtensionContent.
        /// </summary>
        string FirmarXml(string xmlSinFirmar);

        /// <summary>
        /// Verifies the embedded ds:Signature in the signed XML.
        /// Returns false if the signature is missing or invalid.
        /// </summary>
        bool ValidarFirma(string xmlFirmado);
    }
}
