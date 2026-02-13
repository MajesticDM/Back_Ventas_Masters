using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class FacturaConfig : IEntityTypeConfiguration<Factura>
    {
        public void Configure(EntityTypeBuilder<Factura> entity)
        {
            entity.HasKey(e => e.IdFactura).HasName("PK__FACTURAS__4A921BEDDEC6E5F8");

            entity.ToTable("FACTURAS");

            entity.Property(e => e.IdFactura)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ID_FACTURA");
            entity.Property(e => e.CostoTotal)
                .HasColumnType("numeric(18, 2)")
                .HasColumnName("COSTO_TOTAL");
            entity.Property(e => e.Estado).HasColumnName("ESTADO");
            entity.Property(e => e.FechaVenta)
                .HasColumnType("datetime")
                .HasColumnName("FECHA_VENTA");
            entity.Property(e => e.IdxCliente)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_CLIENTE");
            entity.Property(e => e.IdxUsuario)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_USUARIO");

            entity.HasOne(d => d.IdxClienteNavigation).WithMany(p => p.Facturas)
                .HasForeignKey(d => d.IdxCliente)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__FACTURAS__IDX_CL__18EBB532");

            entity.HasOne(d => d.IdxUsuarioNavigation).WithMany(p => p.Facturas)
                .HasForeignKey(d => d.IdxUsuario)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__FACTURAS__IDX_US__19DFD96B");
        }
    }
}
