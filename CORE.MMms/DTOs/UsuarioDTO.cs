namespace CORE.MMms.DTOs;

public partial class UsuarioDTOs
{
    public decimal UsuarioId { get; set; }

    public decimal IdxUsuarioTipo { get; set; }

    public decimal IdxDatosPersonales { get; set; }

    public string Usuario1 { get; set; } = null!;

    public string Contraseña { get; set; } = null!;

    public DateTime FechaCreacion { get; set; }

    public bool Estados { get; set; }

    public byte[]? Foto { get; set; }
}
