namespace CORE.MMms.DTOs;

public partial class ServicioDTOs
{
    public decimal ServicioId { get; set; }

    public string Servicio1 { get; set; } = null!;

    public string Descripcion { get; set; } = null!;

    public double? CostoRegular { get; set; }

    public bool Estados { get; set; }

}
