namespace CORE.MMms.DTOs;

public class ClienteDTOs
{
    public string? Accion { get; set; }

    public decimal? clientE_ID { get; set; }
    public string? identificacion { get; set; }

    public string nombres { get; set; }
    public string? apellidos { get; set; }
    public string? numerO_TELEFONO { get; set; }

    public bool? clientE_REGULAR { get; set; }
    public bool? biT_PERMITE_WHATSAPP { get; set; }
    public bool? biT_PERMITE_MAIL { get; set; }

    public string? correO_ELECTRONICO { get; set; }
    public string? direccioN_FISCAL { get; set; }

    public decimal? idX_TIPO_DOCUMENTO { get; set; }
    public decimal? idX_REGIMEN_TRIBUTARIO { get; set; }
    public decimal? idX_RESPONSABILIDAD_FISCAL { get; set; }

}
