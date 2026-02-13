using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class ServiciosConf : IEntityTypeConfiguration<Servicio>
    {
        public void Configure(EntityTypeBuilder<Servicio> entity)
        {

            entity.HasKey(e => e.ServicioId).HasName("PK__SERVICIOS__30358F5ACD7E7C27");

            entity.ToTable("SERVICIOS");

            entity.Property(e => e.ServicioId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("SERVICIO_ID");
            entity.Property(e => e.CostoRegular).HasColumnName("COSTO_REGULAR");
            entity.Property(e => e.Descripcion)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("DESCRIPCION");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.Servicio1)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("SERVICIO");

        }
    }
}
