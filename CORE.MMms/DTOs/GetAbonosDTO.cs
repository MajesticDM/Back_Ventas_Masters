namespace CORE.MMms.DTOs;

public class GetAbonosDto
{
    public DateTime? fecha_inicial {get; set;}
    public DateTime? fecha_final {get; set;}
    public decimal? idx_cliente { get; set; }
    public decimal? idx_proveedor { get; set; }
    public int pagina { get; set; } = 1;
    public int tamano_pagina { get; set; } = 10;
}
