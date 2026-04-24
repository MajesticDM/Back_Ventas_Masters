namespace CORE.MMms.DTOs
{
    // ---- Phase 3: payload returned by GetXmlPendiente (repo) ----
    public class DianXmlPendienteDto
    {
        public string  XmlFirmado   { get; set; } = string.Empty;
        public string  ZipKey       { get; set; } = string.Empty; // e.g. "SETT000001"
        public string  EstadoDian   { get; set; } = string.Empty;
        public string? TrackId      { get; set; }
        public int     AmbienteDian { get; set; } = 2;
    }

    // ---- Phase 3: result returned by EnviarFactura + ConsultarEstado ----
    public class DianEnvioResultDto
    {
        public long    IdFactura         { get; set; }
        public string  EstadoDian        { get; set; } = string.Empty;
        public string? QrDian            { get; set; }
        public string? NotasDian         { get; set; }
        public string? TrackId           { get; set; }
        public string? DianStatusCode    { get; set; }
        public string? DianStatusMessage { get; set; }
    }

    public class DianActualizarEstadoDto
    {
        public long IdFactura { get; set; }
        public string? Cufe { get; set; }
        public string? EstadoDian { get; set; }
        public string? QrDian { get; set; }
        public string? XmlDian { get; set; }
        public string? NotasDian { get; set; }
    }

    public class DianGenerarXmlResultDto
    {
        public long IdFactura { get; set; }
        public string Cufe { get; set; } = string.Empty;
        public string Xml { get; set; } = string.Empty;
        public string EstadoDian { get; set; } = "PENDIENTE";
        public string NumeroFacturaDian { get; set; } = string.Empty;
    }

    // ---- Bulk send result ----
    public class DianLoteResultDto
    {
        public int Total         { get; set; }
        public int Validadas     { get; set; }
        public int Rechazadas    { get; set; }
        public int Pendientes    { get; set; }
        public int Contingencias { get; set; }
        public List<DianEnvioResultDto> Detalle { get; set; } = new();
    }
}
