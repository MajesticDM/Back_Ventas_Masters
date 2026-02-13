using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace INFRA.MMms.Data.Configuraciones
{
    public class CitaConf : IEntityTypeConfiguration<Cita>
    {
        public void Configure(EntityTypeBuilder<Cita> entity)
        {

            entity.HasKey(e => e.ApptId).HasName("PK__CITAS__D5523B5867DDBC80");

            entity.ToTable("CITAS");

            entity.Property(e => e.ApptId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("APPT_ID");
            entity.Property(e => e.FechaCita)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("FECHA_CITA");
            entity.Property(e => e.IdxCliente)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_CLIENTE");
            entity.Property(e => e.IdxEstados)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_ESTADOS");
            entity.Property(e => e.IdxServicio)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_SERVICIO");
            entity.Property(e => e.IdxUsuarioCreador)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_USUARIO_CREADOR");

            entity.HasOne(d => d.IdxClienteNavigation).WithMany(p => p.Cita)
                .HasForeignKey(d => d.IdxCliente)
                .HasConstraintName("FK__CITAS__IDX_CLIEN__3A81B327");

            entity.HasOne(d => d.IdxEstadosNavigation).WithMany(p => p.Cita)
                .HasForeignKey(d => d.IdxEstados)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__CITAS__IDX_ESTAD__3C69FB99");

            entity.HasOne(d => d.IdxServicioNavigation).WithMany(p => p.Cita)
                .HasForeignKey(d => d.IdxServicio)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__CITAS__IDX_SERVI__3B75D760");

            entity.HasOne(d => d.IdxUsuarioCreadorNavigation).WithMany(p => p.Cita)
                .HasForeignKey(d => d.IdxUsuarioCreador)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__CITAS__IDX_USUAR__3D5E1FD2");

        }
    }
}
