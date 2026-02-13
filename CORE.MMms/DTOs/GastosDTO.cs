namespace CORE.MMms.DTOs;

public class GastoDto
{
    public int? iD_GASTO { get; set; }
    public string? nombre { get; set; }
    public decimal? costo { get; set; }
    public int? cantidad { get; set; }
    public string? descripcion { get; set; }
    public bool? eS_FIJO { get; set; }
    public bool? activo { get; set; }
}
