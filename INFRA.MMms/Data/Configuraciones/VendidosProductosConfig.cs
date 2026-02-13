using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class VendidosProductoConf : IEntityTypeConfiguration<VendidoProducto>
    {
        public void Configure(EntityTypeBuilder<VendidoProducto> entity)
        {

            entity.HasKey(e => e.IdVendidoProduct);

            entity.ToTable("VENDIDO_PRODUCTOS");

            entity.Property(e => e.IdVendidoProduct)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ID_VENDIDO_PRODUCT");
            entity.Property(e => e.IdxFactura)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_FACTURA");
            entity.Property(e => e.IdxProducto)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_PRODUCTO");
            entity.Property(e => e.Quantity)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("QUANTITY");
            entity.Property(e => e.TotalCost).HasColumnName("TOTAL_COST");

            entity.HasOne(d => d.IdxFacturaNavigation).WithMany(p => p.VendidoProductos)
                .HasForeignKey(d => d.IdxFactura)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__VENDIDO_P__IDX_F__2BFE89A6");

            entity.HasOne(d => d.IdxProductoNavigation).WithMany(p => p.VendidoProductos)
                .HasForeignKey(d => d.IdxProducto)
                .HasConstraintName("FK__VENDIDO_PROD__IDX_P__4D94879B");

        }
    }
}
