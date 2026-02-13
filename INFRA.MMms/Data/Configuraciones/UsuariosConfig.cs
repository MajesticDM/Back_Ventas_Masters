using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class UsuariosConf : IEntityTypeConfiguration<Usuario>
    {
        public void Configure(EntityTypeBuilder<Usuario> entity)
        {

            entity.HasKey(e => e.UsuarioId).HasName("PK__USUARIOS__9248D090F9207F65");

            entity.ToTable("USUARIOS");

            entity.Property(e => e.UsuarioId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("USUARIO_ID");
            entity.Property(e => e.Contraseña)
                .IsUnicode(false)
                .HasColumnName("CONTRASEÑA");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.FechaCreacion)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("FECHA_CREACION");
            entity.Property(e => e.Foto).HasColumnName("FOTO");
            entity.Property(e => e.IdxDatosPersonales)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_DATOS_PERSONALES");
            entity.Property(e => e.IdxUsuarioTipo)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_USUARIO_TIPO");
            entity.Property(e => e.Usuario1)
                .IsUnicode(false)
                .HasColumnName("USUARIO");

            entity.HasOne(d => d.IdxDatosPersonalesNavigation).WithMany(p => p.Usuarios)
                .HasForeignKey(d => d.IdxDatosPersonales)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__USUARIOS__IDX_PERSO__3B75D760");

            entity.HasOne(d => d.IdxUsuarioTipoNavigation).WithMany(p => p.Usuarios)
                .HasForeignKey(d => d.IdxUsuarioTipo)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__USUARIOS__IDX_US__440B1D61");

        }
    }
}
