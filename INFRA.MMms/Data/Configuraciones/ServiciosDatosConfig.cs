using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace INFRA.MMms.Data.Configuraciones
{
    public class ServiciosDadoConf : IEntityTypeConfiguration<ServiciosDado>
    {
        public void Configure(EntityTypeBuilder<ServiciosDado> entity)
        {

            entity.HasKey(e => e.ServicioDadosId).HasName("PK__SERVICIOS__6C523903D4464705");

            entity.ToTable("SERVICIOS_DADOS");

            entity.Property(e => e.ServicioDadosId)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("SERVICIO_DADOS_ID");
            entity.Property(e => e.BitVehiculoInicial).HasColumnName("BIT_VEHICULO_INICIAL");
            entity.Property(e => e.ClienteDejoLlaves).HasColumnName("CLIENTE_DEJO_LLAVES");
            entity.Property(e => e.ColorVehiculo)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("COLOR_VEHICULO");
            entity.Property(e => e.CostoAdicional).HasColumnName("COSTO_ADICIONAL");
            entity.Property(e => e.DescripcionLlaves)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("DESCRIPCION_LLAVES");
            entity.Property(e => e.FechaServicioDado)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("FECHA_SERVICIO_DADO");
            entity.Property(e => e.IdxFactura)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_FACTURA");
            entity.Property(e => e.IdxServicio)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_SERVICIO");
            entity.Property(e => e.MarcaVehiculo)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasColumnName("MARCA_VEHICULO");
            entity.Property(e => e.PlacaVehiculo)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasColumnName("PLACA_VEHICULO");
            entity.Property(e => e.TotalCost).HasColumnName("TOTAL_COST");

            entity.HasOne(d => d.IdxFacturaNavigation).WithMany(p => p.ServiciosDados)
                .HasForeignKey(d => d.IdxFactura)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__SERVICIOS__IDX_F__282DF8C2");

            entity.HasOne(d => d.IdxServicioNavigation).WithMany(p => p.ServiciosDados)
                .HasForeignKey(d => d.IdxServicio)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__SERVICIOS___IDX_S__47DBAE45");

        }
    }
}
