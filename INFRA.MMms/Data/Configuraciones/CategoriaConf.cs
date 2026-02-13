using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class CategoriaConf : IEntityTypeConfiguration<Categoria>
    {
        public void Configure(EntityTypeBuilder<Categoria> entity)
        {

            entity.HasKey(e => e.CategoriaId).HasName("PK__CATEGORI__D849E75C9111F5BE");

            entity.ToTable("CATEGORIAS");

            entity.Property(e => e.CategoriaId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("CATEGORIA_ID");
            entity.Property(e => e.Categoria1)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("CATEGORIA");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");

        }
    }
}
