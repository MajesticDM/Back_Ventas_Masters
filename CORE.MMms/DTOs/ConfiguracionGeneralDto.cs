namespace CORE.MMms.DTOs;

public class ConfiguracionGeneralDto
{
    public decimal? id_configuracion { get; set; }
    public string? nombre_legal { get; set; }
    public string? nit_empresa { get; set; }
    public string? email_empresa { get; set; }
    public string? direccion { get; set; }
    public string? telefono { get; set; }
    public string? prefijo_pais { get; set; }
    public bool? envio_whatsapp { get; set; }
    public bool? envio_correos { get; set; }
    public string? api_whatsapp { get; set; }
    public string? token_permanente_whatsapp { get; set; }
    public string? id_telefono_whatsapp { get; set; }
    public string? version_whatsapp { get; set; }
    public decimal? porcentajE_GANANCIA { get; set; }
    public bool? biT_PONDERADO { get; set; }
}
