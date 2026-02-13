namespace CORE.MMms.Entidades
{
    public class CuerpoCompra
    {
        public decimal? producto  {get; set;}
        public bool? existente  {get; set;}
        public string? productoNombre  {get; set;}
        public string? productoNombreSeleccionado  {get; set;}
        public decimal? cantidad  {get; set;}
        public decimal? costoUnidad  {get; set;}
        public decimal? costoTotal  {get; set;}
        public decimal? categoriaId  {get; set;}
        public string? categoriaNombre  { get; set; }
        public decimal usuarioId  { get; set; }
    }
}
