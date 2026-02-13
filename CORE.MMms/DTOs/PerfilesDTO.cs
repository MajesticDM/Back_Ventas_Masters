namespace CORE.MMms.DTOs;

public class perfilesDto
{
    public decimal? iD_PERFIL { get; set; }
    public string? desC_PERFIL { get; set; }
    public bool? eS_ADMIN { get; set; }

    public bool? biT_ENTRAR_CLIENTES { get; set; }
    public bool? biT_ENTRAR_USUARIOS { get; set; }
    public bool? biT_ENTRAR_PRODUCTOS { get; set; }
    public bool? biT_ENTRAR_ACTIVOS { get; set; }
    public bool? biT_ENTRAR_FINANZAS { get; set; }
    public bool? biT_ENTRAR_REPORTES { get; set; }
    public bool? biT_ENTRAR_COMPRAS { get; set; }
    public bool? biT_ENTRAR_VENTAS { get; set; }
    public bool? biT_ENTRAR_CONFIGURACION { get; set; }

    public bool? biT_ENTRAR_PROVEEDORES { get; set; }
    public bool? biT_ENTRAR_PERFILES { get; set; }
    public bool? biT_ENTRAR_ABONOS { get; set; }
}
