using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class ProductosConf : IEntityTypeConfiguration<Producto>
    {
        public void Configure(EntityTypeBuilder<Producto> entity)
        {

            entity.HasKey(e => e.ProductId).HasName("PK__PRODUCTOS__52B417637B027325");

            entity.ToTable("PRODUCTOS");

            entity.Property(e => e.ProductId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("PRODUCT_ID");
            entity.Property(e => e.CostoXUnidad).HasColumnName("COSTO_X_UNIDAD");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.IdxCategoria)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_CATEGORIA");
            entity.Property(e => e.Producto1)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("PRODUCTO");
            entity.Property(e => e.Quantity)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("QUANTITY");

            entity.HasOne(d => d.IdxCategoriaNavigation).WithMany(p => p.Productos)
                .HasForeignKey(d => d.IdxCategoria)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__PRODUCTOS__IDX_CA__4316F928");

        }
    }
}
