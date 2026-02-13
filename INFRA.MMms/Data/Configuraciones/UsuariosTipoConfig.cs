using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class UsuariosTipoConf : IEntityTypeConfiguration<UsuariosTipo>
    {
        public void Configure(EntityTypeBuilder<UsuariosTipo> entity)
        {

            entity.HasKey(e => e.UsuarioTipoId).HasName("PK__USUARIOS__A1E1A534F258D011");

            entity.ToTable("USUARIOS_TIPO");

            entity.Property(e => e.UsuarioTipoId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("USUARIO_TIPO_ID");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.UsuarioTipo)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("USUARIO_TIPO");

        }
    }
}
