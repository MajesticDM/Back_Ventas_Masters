using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class ClientesConf : IEntityTypeConfiguration<Cliente>
    {
        public void Configure(EntityTypeBuilder<Cliente> entity)
        {


            entity.HasKey(e => e.ClienteId).HasName("PK__CLIENTEES__1ED67F69A6137994");

            entity.ToTable("CLIENTES");

            entity.Property(e => e.ClienteId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("CLIENTE_ID");
            entity.Property(e => e.Apellidos)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("APELLIDOS");
            entity.Property(e => e.ClienteFoto).HasColumnName("CLIENTE_FOTO");
            entity.Property(e => e.ClienteRegular).HasColumnName("CLIENTE_REGULAR");
            entity.Property(e => e.ColorVehiculo)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("COLOR_VEHICULO");
            entity.Property(e => e.MarcaVehiculo)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("MARCA_VEHICULO");
            entity.Property(e => e.Nombres)
                .HasMaxLength(10)
                .IsFixedLength()
                .HasColumnName("NOMBRES");

            entity.Property(e => e.NumeroTelefono)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("NUMERO_TELEFONO");

            entity.Property(e => e.PlacaVehiculo)
                .HasMaxLength(10)
                .IsFixedLength()
                .HasColumnName("PLACA_VEHICULO");

            entity.Property(e => e.correo_electronico)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("CORREO_ELECTRONICO");

            entity.Property(e => e.TieneVehiculo).HasColumnName("TIENE_VEHICULO");
            entity.Property(e => e.bitAceptaWhatsapp).HasColumnName("BIT_PERMITE_WHATSAPP");
            entity.Property(e => e.bitAceptaCorreo).HasColumnName("BIT_PERMITE_MAIL");

        }
    }
}
