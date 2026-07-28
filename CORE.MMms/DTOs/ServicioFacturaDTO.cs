namespace CORE.MMms.DTOs;

public class ServicioFacturaDto
{
    public decimal IdxServicio { get; set; }
    public bool ClienteDejoLlaves { get; set; }
    public string? DescripcionLlaves { get; set; }
    public bool? BitVehiculoInicial { get; set; }
    public string? PlacaVehiculo { get; set; }
    public string? ColorVehiculo { get; set; }
    public string? MarcaVehiculo { get; set; }
    public double? CostoAdicional { get; set; }
    public double TotalCost { get; set; }
}
