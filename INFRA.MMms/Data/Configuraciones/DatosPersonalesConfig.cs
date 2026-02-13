using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class DatosPersonalesConf : IEntityTypeConfiguration<DatosPersonale>
    {
        public void Configure(EntityTypeBuilder<DatosPersonale> entity)
        {

            entity.HasKey(e => e.DatosPersonalesId).HasName("PK__PERSONAL__D6CD15EB32B33DF9");

            entity.ToTable("DATOS_PERSONALES");

            entity.Property(e => e.DatosPersonalesId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("DATOS_PERSONALES_ID");
            entity.Property(e => e.Apellidos)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("APELLIDOS");
            entity.Property(e => e.Email)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("EMAIL");
            entity.Property(e => e.Estados).HasColumnName("ESTADOS");
            entity.Property(e => e.Foto).HasColumnName("FOTO");
            entity.Property(e => e.Nombres)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("NOMBRES");
            entity.Property(e => e.NumeroTelefono)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("NUMERO_TELEFONO");

        }
    }
}
