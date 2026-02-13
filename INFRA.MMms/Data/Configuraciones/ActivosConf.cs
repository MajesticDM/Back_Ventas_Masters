using CORE.MMms;
using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class ActivosConf : IEntityTypeConfiguration<Activo>
    {
        public void Configure(EntityTypeBuilder<Activo> entity)
        {

            entity.HasKey(e => e.IdActivo).HasName("PK__ACTIVOS__C3EE2353F67283FC");

            entity.ToTable("ACTIVOS");

            entity.Property(e => e.IdActivo)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ID_ACTIVO");
            entity.Property(e => e.Activo1)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("ACTIVO");
            entity.Property(e => e.CostoXUnidad).HasColumnName("COSTO_X_UNIDAD");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.Quantity)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("QUANTITY");

        }
    }
}
