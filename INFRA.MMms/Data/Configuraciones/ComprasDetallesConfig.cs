using CORE.MMms;
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
    public class ComprasDetallesConfig : IEntityTypeConfiguration<ComprasDetalle>
    {
        public void Configure(EntityTypeBuilder<ComprasDetalle> entity)
        {
            entity.HasKey(e => e.IdCompraDetalle).HasName("PK__COMPRAS___7D8570FD5D2D920C");

            entity.ToTable("COMPRAS_DETALLES");

            entity.Property(e => e.IdCompraDetalle)
                .ValueGeneratedOnAdd()
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("ID_COMPRA_DETALLE");
            entity.Property(e => e.Cantidad)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("CANTIDAD");
            entity.Property(e => e.ComentarioProducto)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("COMENTARIO_PRODUCTO");
            entity.Property(e => e.Costo)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("COSTO");
            entity.Property(e => e.IdxActivo)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_ACTIVO");
            entity.Property(e => e.IdxCompra)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_COMPRA");
            entity.Property(e => e.IdxProducto)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_PRODUCTO");
            entity.Property(e => e.IdxServicio)
                .HasColumnType("numeric(18, 0)")
                .HasColumnName("IDX_SERVICIO");
        }
    }
}
