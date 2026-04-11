using CORE.MMms.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Drawing;
using System.Drawing.Printing;
using System.Globalization;

namespace INFRA.MMms.Services
{
    public class PrintService : IPrintService
    {
        private const int LineWidth = 40;
        private static readonly CultureInfo CulCO = new CultureInfo("es-CO");
        private static readonly object _logLock = new object();

        private readonly IReportes _reportes;
        private readonly string _nombreEmpresa;
        private readonly string _nombreImpresora;
        private readonly string _logPath;

        public PrintService(IReportes reportes, IConfiguration config)
        {
            _reportes        = reportes;
            _nombreEmpresa   = config["PrintSettings:NombreEmpresa"]   ?? "VENTAS MASTERS";
            _nombreImpresora = config["PrintSettings:NombreImpresora"] ?? "HP Laser MFP 135w";
            _logPath         = config["PrintSettings:LogPath"]         ?? "print.log";
        }

        // ----------------------------------------------------------------
        // Recibo de venta
        // ----------------------------------------------------------------
        public void ImprimirFactura(decimal idFactura)
        {
            try
            {
                var ds = _reportes.GetDetalleFactura(idFactura);
                if (ds.Tables.Count < 1 || ds.Tables[0].Rows.Count == 0)
                {
                    Log($"[FACTURA] id={idFactura} → SIN DATOS en SP_DETALLE_FACTURA");
                    return;
                }

                var cab    = ds.Tables[0].Rows[0];
                var lineas = ds.Tables.Count > 1 ? ds.Tables[1] : new DataTable();

                var lines = new List<string>();

                lines.Add(Center(_nombreEmpresa));
                lines.Add(Center($"Factura #{cab["id_factura"]} - {cab["fecha_venta"]}"));
                lines.Add(Sep());

                lines.Add($"Cliente: {cab["cliente"]}");

                bool esFinal = cab["consumidor_final"] != DBNull.Value && Convert.ToBoolean(cab["consumidor_final"]);
                lines.Add(esFinal
                    ? "Consumidor Final"
                    : $"ID: {Val(cab, "identificacion_cliente")}");

                lines.Add($"Tel: {Val(cab, "telefono_cliente")}");
                lines.Add($"Vendedor: {cab["vendedor"]}");
                lines.Add(Sep());

                lines.Add("  " + "Cant".PadLeft(8) + "$/Unit".PadLeft(14) + "Total".PadLeft(14));
                lines.Add(Sep());

                foreach (DataRow lr in lineas.Rows)
                {
                    decimal gramaje   = lr["gramaje_total"] == DBNull.Value ? 0 : Convert.ToDecimal(lr["gramaje_total"]);
                    decimal cantidad  = Convert.ToDecimal(lr["cantidad"]);
                    decimal totalLinea = Convert.ToDecimal(lr["total_linea"]);

                    // Derivar precio de venta desde el total (precio_unitario del SP devuelve el costo)
                    decimal divisor   = cantidad == 0 ? 1 : cantidad;
                    decimal precioVenta = divisor == 0 ? 0 : totalLinea / divisor;

                    string cantCol   = gramaje > 0 ? $"{cantidad}uds/{gramaje}g" : $"{cantidad}uds";
                    string precioCol = gramaje > 0 ? $"{Cop(precioVenta)}/uds" : Cop(precioVenta);
                    string totalCol  = Cop(totalLinea);
                    string nombre    = lr["nombre"].ToString()!;

                    lines.Add(nombre);
                    lines.Add("  " + cantCol.PadLeft(8) + precioCol.PadLeft(14) + totalCol.PadLeft(14));
                }

                lines.Add(Sep());

                decimal iva       = Num(cab, "valor_iva");
                decimal total     = Num(cab, "total");
                decimal pagado    = Num(cab, "pagado");
                decimal pendiente = Num(cab, "pendiente");

                lines.Add(RightPair("IVA:", Cop(iva)));
                lines.Add(RightPair("TOTAL:", Cop(total)));
                lines.Add(RightPair("Cobrado:", Cop(pagado)));
                if (pendiente > 0)
                    lines.Add(RightPair("Pendiente:", Cop(pendiente)));
                lines.Add(RightPair("Forma pago:", cab["forma_pago"].ToString()!));

                string? cufe = cab["cufe_factura"] == DBNull.Value ? null : cab["cufe_factura"]?.ToString();
                if (!string.IsNullOrEmpty(cufe))
                {
                    lines.Add(Sep());
                    lines.Add("CUFE:");
                    for (int i = 0; i < cufe.Length; i += LineWidth)
                        lines.Add(cufe.Substring(i, Math.Min(LineWidth, cufe.Length - i)));
                }

                lines.Add(Sep());
                lines.Add(Center("Gracias por su compra"));
                lines.Add("");
                lines.Add("");

                Imprimir(lines);
                Log($"[FACTURA] id={idFactura} cliente={cab["cliente"]} total={Cop(total)} → OK impresora={_nombreImpresora}");
            }
            catch (Exception ex)
            {
                Log($"[FACTURA] id={idFactura} → ERROR: {ex.Message}");
            }
        }

        // ----------------------------------------------------------------
        // Comprobante de abono
        // ----------------------------------------------------------------
        public void ImprimirAbono(decimal idxFactura, decimal idxUsuario)
        {
            try
            {
                decimal idDetalle = _reportes.GetUltimoAbonoFactura(idxFactura, idxUsuario);
                if (idDetalle == 0)
                {
                    Log($"[ABONO] idxFactura={idxFactura} idxUsuario={idxUsuario} → SIN DETALLE (GetUltimoAbonoFactura devolvio 0)");
                    return;
                }

                var dt = _reportes.GetDetalleAbono(idDetalle);
                if (dt.Rows.Count == 0)
                {
                    Log($"[ABONO] idxFactura={idxFactura} idDetalle={idDetalle} → SIN DATOS en SP_DETALLE_ABONO_VENTA");
                    return;
                }

                var d     = dt.Rows[0];
                var lines = new List<string>();

                lines.Add(Center(_nombreEmpresa));
                lines.Add(Center("Comprobante de Abono"));
                lines.Add(Center(Val(d, "fecha_abono")));
                lines.Add(Sep());

                lines.Add(RightPair("Factura #:", Val(d, "id_factura")));
                lines.Add($"Cliente: {d["cliente"]}");
                lines.Add($"Tel: {Val(d, "telefono_cliente")}");
                lines.Add($"ID: {Val(d, "identificacion_cliente")}");
                lines.Add(Sep());

                lines.Add(RightPair("Total factura:", Cop(Num(d, "total_factura"))));
                lines.Add(RightPair("Total pagado:",  Cop(Num(d, "pagado_total"))));
                lines.Add(Sep());

                lines.Add(RightPair("Abono recibido:", Cop(Num(d, "valor_abonado"))));
                lines.Add(RightPair("Forma pago:", Val(d, "forma_pago")));

                decimal saldo = Num(d, "saldo_restante");
                lines.Add(saldo > 0
                    ? RightPair("Saldo restante:", Cop(saldo))
                    : RightPair("Estado:", "PAGADO EN TOTAL"));

                lines.Add(Sep());
                lines.Add(RightPair("Atendido por:", Val(d, "usuario")));

                string? comentario = d["comentario"] == DBNull.Value ? null : d["comentario"]?.ToString();
                if (!string.IsNullOrEmpty(comentario))
                    lines.Add($"Obs: {comentario}");

                lines.Add(Center("Gracias por su pago"));
                lines.Add("");
                lines.Add("");

                Imprimir(lines);
                Log($"[ABONO] idxFactura={idxFactura} idDetalle={idDetalle} cliente={d["cliente"]} abono={Cop(Num(d, "valor_abonado"))} → OK impresora={_nombreImpresora}");
            }
            catch (Exception ex)
            {
                Log($"[ABONO] idxFactura={idxFactura} idxUsuario={idxUsuario} → ERROR: {ex.Message}");
            }
        }

        // ----------------------------------------------------------------
        // Envio a impresora via System.Drawing.Printing
        // ----------------------------------------------------------------
        private void Imprimir(List<string> lines)
        {
            var capturedLines = lines;
            var doc = new PrintDocument();
            doc.PrinterSettings.PrinterName = _nombreImpresora;

            doc.PrintPage += (_, e) =>
            {
                using var font = new Font("Courier New", 8f, FontStyle.Regular, GraphicsUnit.Point);
                float lineH = font.GetHeight(e.Graphics);
                float x = e.MarginBounds.Left;
                float y = e.MarginBounds.Top;

                foreach (var line in capturedLines)
                {
                    e.Graphics.DrawString(line, font, Brushes.Black, x, y);
                    y += lineH;
                }

                e.HasMorePages = false;
            };

            doc.Print();
        }

        // ----------------------------------------------------------------
        // Log a archivo
        // ----------------------------------------------------------------
        private void Log(string mensaje)
        {
            try
            {
                string linea = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {mensaje}{Environment.NewLine}";
                lock (_logLock)
                {
                    File.AppendAllText(_logPath, linea);
                }
            }
            catch { /* no romper nada si el log falla */ }
        }

        // ----------------------------------------------------------------
        // Helpers
        // ----------------------------------------------------------------
        private static string Cop(decimal v) =>
            "$" + v.ToString("N0", CulCO);

        private static string Center(string text)
        {
            if (text.Length >= LineWidth) return text;
            int pad = (LineWidth - text.Length) / 2;
            return text.PadLeft(text.Length + pad);
        }

        private static string Sep() => new string('-', LineWidth);

        private static string RightPair(string label, string value)
        {
            int space = LineWidth - label.Length - value.Length;
            return label + new string(' ', Math.Max(1, space)) + value;
        }

        private static string Val(DataRow row, string col) =>
            row[col] == DBNull.Value ? "-" : row[col]?.ToString() ?? "-";

        private static decimal Num(DataRow row, string col) =>
            row[col] == DBNull.Value ? 0 : Convert.ToDecimal(row[col]);
    }
}
