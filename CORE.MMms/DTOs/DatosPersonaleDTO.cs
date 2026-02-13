namespace CORE.MMms.DTOs;

public partial class DatosPersonaleDTOs
{
    public decimal DatosPersonalesId { get; set; }

    public string Nombres { get; set; } = null!;

    public string Apellidos { get; set; } = null!;

    public decimal NumeroTelefono { get; set; }

    public string Email { get; set; } = null!;

    public string Foto { get; set; }

    public bool Estados { get; set; }

}
