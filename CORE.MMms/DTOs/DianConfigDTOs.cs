namespace CORE.MMms.DTOs
{
    public class DianEmpresaDto
    {
        public string? NombreComercial                   { get; set; }
        public string? DigitoVerificacion                { get; set; }
        public string? MunicipioDian                     { get; set; }
        public string? DepartamentoDian                  { get; set; }
        public string? CodigoPostal                      { get; set; }
        public int?    IdxTipoDocumentoEmpresa           { get; set; }
        public int?    IdxRegimenTributarioEmpresa       { get; set; }
        public int?    IdxResponsabilidadFiscalEmpresa   { get; set; }
        public int     AmbienteDian                      { get; set; } = 2;
    }

    public class DianResolucionDto
    {
        public string   NumeroResolucion    { get; set; } = string.Empty;
        public DateTime FechaResolucion     { get; set; }
        public DateTime FechaInicio         { get; set; }
        public DateTime FechaFin            { get; set; }
        public string?  Prefijo             { get; set; }
        public long     RangoInicio         { get; set; }
        public long     RangoFin            { get; set; }
        public string   ClaveTecnica        { get; set; } = string.Empty;
        public string   Tipo                { get; set; } = "FC";
    }

    public class DianProductoCamposDto
    {
        public string? CodigoUnspsc { get; set; }
        public int?    IdxTipoIva   { get; set; }
    }

    public class DianClienteCamposDto
    {
        public string? MunicipioDian      { get; set; }
        public string? CodigoPostal       { get; set; }
        public string? DigitoVerificacion { get; set; }
    }

    public class DianPagoCampoDto
    {
        public string? CodigoMedioPagoDian { get; set; }
    }
}
