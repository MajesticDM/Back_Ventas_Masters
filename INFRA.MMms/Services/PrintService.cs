using CORE.MMms.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Printing;
using System.Globalization;

namespace INFRA.MMms.Services
{
    public class PrintService : IPrintService
    {
        private const int LineWidth = 36;
        private static readonly CultureInfo CulCO = new CultureInfo("es-CO");
        private static readonly object _logLock = new object();

        private static readonly ColorMatrix GrayscaleMatrix = new ColorMatrix(new float[][]
        {
            new float[] {0.299f, 0.299f, 0.299f, 0, 0},
            new float[] {0.587f, 0.587f, 0.587f, 0, 0},
            new float[] {0.114f, 0.114f, 0.114f, 0, 0},
            new float[] {0,      0,      0,      1, 0},
            new float[] {0,      0,      0,      0, 1}
        });

        private readonly IReportes _reportes;
        private readonly string _nombreEmpresa;
        private readonly string _nombreImpresora;
        private readonly string _logPath;
        private readonly string _logoPath;

        public PrintService(IReportes reportes, IConfiguration config)
        {
            _reportes        = reportes;
            _nombreEmpresa   = config["PrintSettings:NombreEmpresa"]   ?? "VENTAS MASTERS";
            _nombreImpresora = config["PrintSettings:NombreImpresora"] ?? "HP Laser MFP 135w";
            _logPath         = config["PrintSettings:LogPath"]         ?? "print.log";
            _logoPath        = config["PrintSettings:LogoPath"]        ?? "";
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

                lines.Add(Center("Carrera 53 # 47 - 21, Local 109"));
                lines.Add(Center("C.C Luz del Dia"));
                lines.Add(Center("CEL 323 491 3454"));
                lines.Add(Center("NIT 901838998-0"));

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

                lines.Add("  " + "Cant".PadLeft(8) + "$/Unid".PadLeft(12) + "Total".PadLeft(12));
                lines.Add(Sep());

                foreach (DataRow lr in lineas.Rows)
                {
                    decimal gramaje   = lr["gramaje_total"] == DBNull.Value ? 0 : Convert.ToDecimal(lr["gramaje_total"]);
                    decimal cantidad  = Convert.ToDecimal(lr["cantidad"]);
                    decimal totalLinea = Convert.ToDecimal(lr["total_linea"]);

                    // Derivar precio de venta desde el total (precio_unitario del SP devuelve el costo)
                    decimal divisor   = cantidad == 0 ? 1 : cantidad;
                    decimal precioVenta = divisor == 0 ? 0 : totalLinea / divisor;

                    string cantCol   = gramaje > 0 ? $"{gramaje}g" : $"{cantidad}uds";
                    string precioCol = gramaje > 0 ? $"{Cop(precioVenta)}/U" : Cop(precioVenta);
                    string totalCol  = Cop(totalLinea);
                    string nombre    = lr["nombre"].ToString()!;

                    lines.Add(nombre);
                    lines.Add("  " + cantCol.PadLeft(8) + precioCol.PadLeft(12) + totalCol.PadLeft(12));
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

                Imprimir(lines, conLogo: true);
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

                lines.Add(Center("Carrera 53 # 47 - 21, Local 109"));
                lines.Add(Center("C.C Luz del Día"));
                lines.Add(Center("CEL 323 491 3454"));
                lines.Add(Center("NIT 901838998-0"));

                lines.Add(Center("Comprobante de Abono"));
                lines.Add(Center(Val(d, "fecha_abono")));
                lines.Add(Sep());

                lines.Add($"Factura #: {d["id_factura"]}");
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

                Imprimir(lines, conLogo: true);
                Log($"[ABONO] idxFactura={idxFactura} idDetalle={idDetalle} cliente={d["cliente"]} abono={Cop(Num(d, "valor_abonado"))} → OK impresora={_nombreImpresora}");
            }
            catch (Exception ex)
            {
                Log($"[ABONO] idxFactura={idxFactura} idxUsuario={idxUsuario} → ERROR: {ex.Message}");
            }
        }

        // ----------------------------------------------------------------
        // Recibo de compra
        // ----------------------------------------------------------------
        public void ImprimirCompra(decimal idCompra)
        {
            try
            {
                var ds = _reportes.GetDetalleCompra(idCompra);
                if (ds.Tables.Count < 1 || ds.Tables[0].Rows.Count == 0)
                {
                    Log($"[COMPRA] id={idCompra} → SIN DATOS en SP_DETALLE_COMPRA");
                    return;
                }

                var cab    = ds.Tables[0].Rows[0];
                var lineas = ds.Tables.Count > 1 ? ds.Tables[1] : new DataTable();

                var lines = new List<string>();

                lines.Add(Center(_nombreEmpresa));

                lines.Add(Center("Carrera 53 # 47 - 21, Local 109"));
                lines.Add(Center("C.C Luz del Dia"));
                lines.Add(Center("CEL 323 491 3454"));
                lines.Add(Center("NIT 901838998-0"));

                lines.Add(Center($"Compra #{cab["id_compra"]} - {cab["fecha_compra"]}"));
                lines.Add(Sep());

                lines.Add($"Proveedor: {cab["proveedor"]}");
                lines.Add($"Tel: {Val(cab, "telefono_proveedor")}");
                lines.Add($"Comprador: {cab["comprador"]}");
                lines.Add(Sep());

                lines.Add("  " + "Cant".PadLeft(8) + "$/Unid".PadLeft(12) + "Total".PadLeft(12));
                lines.Add(Sep());

                foreach (DataRow lr in lineas.Rows)
                {
                    decimal gramaje    = lr["gramaje_total"] == DBNull.Value ? 0 : Convert.ToDecimal(lr["gramaje_total"]);
                    decimal cantidad   = Convert.ToDecimal(lr["cantidad"]);
                    decimal totalLinea = Convert.ToDecimal(lr["total_linea"]);

                    decimal divisor     = cantidad == 0 ? 1 : cantidad;
                    decimal costoUnidad = divisor == 0 ? 0 : totalLinea / divisor;

                    string cantCol   = gramaje > 0 ? $"{gramaje}g" : $"{cantidad}uds";
                    string precioCol = gramaje > 0 ? $"{Cop(costoUnidad)}/U" : Cop(costoUnidad);
                    string totalCol  = Cop(totalLinea);
                    string nombre    = lr["nombre"].ToString()!;

                    lines.Add(nombre);
                    lines.Add("  " + cantCol.PadLeft(8) + precioCol.PadLeft(12) + totalCol.PadLeft(12));
                }

                lines.Add(Sep());

                decimal total     = Num(cab, "total");
                decimal pagado    = Num(cab, "pagado");
                decimal pendiente = Num(cab, "pendiente");
                decimal inicial   = Num(cab, "pago_inicial");

                lines.Add(RightPair("TOTAL:", Cop(total)));
                if (inicial > 0)
                    lines.Add(RightPair("Pago inicial:", Cop(inicial)));
                lines.Add(RightPair("Pagado:", Cop(pagado)));
                if (pendiente > 0)
                    lines.Add(RightPair("Pendiente:", Cop(pendiente)));
                lines.Add(RightPair("Forma pago:", cab["forma_pago"].ToString()!));

                lines.Add(Sep());
                lines.Add(Center("Recibo de compra"));
                lines.Add("");
                lines.Add("");

                Imprimir(lines, conLogo: true);
                Log($"[COMPRA] id={idCompra} proveedor={cab["proveedor"]} total={Cop(total)} → OK impresora={_nombreImpresora}");
            }
            catch (Exception ex)
            {
                Log($"[COMPRA] id={idCompra} → ERROR: {ex.Message}");
            }
        }

        // ----------------------------------------------------------------
        // Comprobante de abono a proveedor
        // ----------------------------------------------------------------
        public void ImprimirAbonoCompra(decimal idxCompra, decimal idxUsuario)
        {
            try
            {
                decimal idDetalle = _reportes.GetUltimoAbonoCompra(idxCompra, idxUsuario);
                if (idDetalle == 0)
                {
                    Log($"[ABONO-COMPRA] idxCompra={idxCompra} idxUsuario={idxUsuario} → SIN DETALLE (GetUltimoAbonoCompra devolvio 0)");
                    return;
                }

                var dt = _reportes.GetDetalleAbonoCompra(idDetalle);
                if (dt.Rows.Count == 0)
                {
                    Log($"[ABONO-COMPRA] idxCompra={idxCompra} idDetalle={idDetalle} → SIN DATOS en SP_DETALLE_ABONO_COMPRA");
                    return;
                }

                var d     = dt.Rows[0];
                var lines = new List<string>();

                lines.Add(Center(_nombreEmpresa));

                lines.Add(Center("Carrera 53 # 47 - 21, Local 109"));
                lines.Add(Center("C.C Luz del Dia"));
                lines.Add(Center("CEL 323 491 3454"));
                lines.Add(Center("NIT 901838998-0"));

                lines.Add(Center("Comprobante de Abono a Proveedor"));
                lines.Add(Center(Val(d, "fecha_abono")));
                lines.Add(Sep());

                lines.Add(RightPair("Compra #:", Val(d, "id_compra")));
                lines.Add($"Proveedor: {d["proveedor"]}");
                lines.Add($"Tel: {Val(d, "telefono_proveedor")}");
                lines.Add(Sep());

                lines.Add(RightPair("Total compra:", Cop(Num(d, "total_compra"))));
                lines.Add(RightPair("Total pagado:", Cop(Num(d, "pagado_total"))));
                lines.Add(Sep());

                lines.Add(RightPair("Abono realizado:", Cop(Num(d, "valor_abonado"))));
                lines.Add(RightPair("Forma pago:", Val(d, "forma_pago")));

                decimal saldo = Num(d, "saldo_restante");
                lines.Add(saldo > 0
                    ? RightPair("Saldo restante:", Cop(saldo))
                    : RightPair("Estado:", "PAGADO EN TOTAL"));

                lines.Add(Sep());
                lines.Add(RightPair("Registrado por:", Val(d, "usuario")));

                string? comentario = d["comentario"] == DBNull.Value ? null : d["comentario"]?.ToString();
                if (!string.IsNullOrEmpty(comentario))
                    lines.Add($"Obs: {comentario}");

                lines.Add(Center("Comprobante de pago"));
                lines.Add("");
                lines.Add("");

                Imprimir(lines, conLogo: true);
                Log($"[ABONO-COMPRA] idxCompra={idxCompra} idDetalle={idDetalle} proveedor={d["proveedor"]} abono={Cop(Num(d, "valor_abonado"))} → OK impresora={_nombreImpresora}");
            }
            catch (Exception ex)
            {
                Log($"[ABONO-COMPRA] idxCompra={idxCompra} idxUsuario={idxUsuario} → ERROR: {ex.Message}");
            }
        }

        // ----------------------------------------------------------------
        // Envio a impresora via System.Drawing.Printing
        // ----------------------------------------------------------------
        private void Imprimir(List<string> lines, bool conLogo = false)
        {
            using var logo = conLogo ? CargarLogo() : null;

            for (int copia = 0; copia < 2; copia++)
            {
                var capturedLines = lines;
                var doc = new PrintDocument();
                doc.PrinterSettings.PrinterName = _nombreImpresora;
                doc.DefaultPageSettings.Margins = new Margins(0, 0, 0, 0);

                doc.PrintPage += (_, e) =>
                {
                    using var font = new Font("Courier New", 9f, FontStyle.Bold, GraphicsUnit.Point);
                    float lineH = font.GetHeight(e.Graphics);
                    float x = e.PageBounds.Left + 4;
                    float y = e.PageBounds.Top + 4;

                    if (logo != null)
                        y = DibujarLogoCentrado(e.Graphics, e.PageBounds, logo, y + 12);

                    foreach (var line in capturedLines)
                    {
                        e.Graphics.DrawString(line, font, Brushes.Black, x, y);
                        y += lineH;
                    }

                    e.HasMorePages = false;
                };

                doc.Print();
            }
        }

        // ----------------------------------------------------------------
        // Logo de la empresa: cargado desde PrintSettings:LogoPath,
        // impreso centrado y en blanco y negro (escala de grises).
        // ----------------------------------------------------------------
        private Bitmap? CargarLogo()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_logoPath) || !File.Exists(_logoPath))
                    return null;

                byte[] bytes = File.ReadAllBytes(_logoPath);
                using var ms = new MemoryStream(bytes);
                return new Bitmap(ms);
            }
            catch (Exception ex)
            {
                Log($"[LOGO] No se pudo cargar '{_logoPath}': {ex.Message}");
                return null;
            }
        }

        private static float DibujarLogoCentrado(Graphics graphics, Rectangle pageBounds, Bitmap logo, float y)
        {
            float maxWidth = Math.Max(1, pageBounds.Width - 8);
            float scale = Math.Min(1f, maxWidth / logo.Width);
            float imgWidth = logo.Width * scale;
            float imgHeight = logo.Height * scale;
            float imgX = pageBounds.Left + (pageBounds.Width - imgWidth) / 2f;

            using var attributes = new ImageAttributes();
            attributes.SetColorMatrix(GrayscaleMatrix);

            graphics.DrawImage(
                logo,
                new Rectangle((int)imgX, (int)y, (int)imgWidth, (int)imgHeight),
                0, 0, logo.Width, logo.Height,
                GraphicsUnit.Pixel, attributes);

            return y + imgHeight + 30;
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

        private static string Sep() => new string('_', LineWidth);

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
