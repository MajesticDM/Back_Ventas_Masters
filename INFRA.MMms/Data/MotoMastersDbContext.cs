using System;
using System.Collections.Generic;
using System.Reflection;
using CORE.MMms;
using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;

namespace INFRA.MMms.Data;

public partial class MotoMastersDbContext : DbContext
{
    public MotoMastersDbContext()
    {
    }

    public MotoMastersDbContext(DbContextOptions<MotoMastersDbContext> options)
        : base(options)
    {
    }
    public virtual DbSet<Cita> Cita { get; set; }
    public virtual DbSet<CitasEstado> CitasEstado { get; set; }
    public virtual DbSet<Categoria> Categoria { get; set; }
    public virtual DbSet<Cliente> Cliente { get; set; }
    public virtual DbSet<DatosPersonale> DatosPersonale { get; set; }
    public virtual DbSet<Producto> Producto { get; set; }
    public virtual DbSet<Servicio> Servicio { get; set; }
    public virtual DbSet<Factura> Facturas { get; set; }
    public virtual DbSet<ServiciosDado> ServiciosDado { get; set; }
    public virtual DbSet<VendidoProducto> VendidoProducto { get; set; }
    public virtual DbSet<Usuario> Usuario { get; set; }
    public virtual DbSet<UsuariosTipo> UsuariosTipo { get; set; }
    public virtual DbSet<Compra> Compras { get; set; }
    public virtual DbSet<Activo> Activos { get; set; }

    public virtual DbSet<ComprasDetalle> ComprasDetalles { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());
    }

}
