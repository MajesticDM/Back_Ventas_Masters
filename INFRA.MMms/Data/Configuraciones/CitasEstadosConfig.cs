using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class CitasEstadosConf : IEntityTypeConfiguration<CitasEstado>
    {
        public void Configure(EntityTypeBuilder<CitasEstado> entity)
        {

            entity.HasKey(e => e.EstadosId).HasName("PK__CITAS_ES__1138E7EDB6B398AA");

            entity.ToTable("CITAS_ESTADOS");

            entity.Property(e => e.EstadosId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ESTADOS_ID");
            entity.Property(e => e.CitasEstados)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("CITAS_ESTADOS");

        }
    }
}
