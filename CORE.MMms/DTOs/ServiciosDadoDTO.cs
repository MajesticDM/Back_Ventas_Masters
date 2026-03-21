namespace CORE.MMms.DTOs;

public partial class ServiciosDadoDTOs
{
    public decimal? idxServicio { get; set; }
    public bool? ClienteDejoLlaves { get; set; }
    public string? DescripcionLlaves { get; set; }
    public bool BitVehiculoInicial { get; set; }
    public string? PlacaVehiculo { get; set; }
    public string? ColorVehiculo { get; set; }
    public string? MarcaVehiculo { get; set; }
    public decimal? totalCost { get; set; }
    public bool CostoAdicional { get; set; }
}
