using CORE.MMms.Entidades;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace INFRA.MMms.Data.Configuraciones
{
    public class CompraConfig : IEntityTypeConfiguration<Compra>
    {
        public void Configure(EntityTypeBuilder<Compra> entity)
        {
            entity.HasKey(e => e.IdCompra).HasName("PK__COMPRAS__16C0FA95F27D773C");

            entity.ToTable("COMPRAS");

            entity.Property(e => e.IdCompra)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ID_COMPRA");
            entity.Property(e => e.ComentarioCompra)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("COMENTARIO_COMPRA");
            entity.Property(e => e.CostoTotal)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("COSTO_TOTAL");
            entity.Property(e => e.FechaCompra)
                .HasColumnType("datetime")
                .HasColumnName("FECHA_COMPRA");
            entity.Property(e => e.IdxUsuarioComprador)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_USUARIO_COMPRADOR");
        }
    }
}
