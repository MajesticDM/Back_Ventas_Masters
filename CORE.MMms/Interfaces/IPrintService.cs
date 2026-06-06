namespace CORE.MMms.Interfaces
{
    public interface IPrintService
    {
        /// <summary>Imprime el recibo de una venta en la impresora configurada.</summary>
        void ImprimirFactura(decimal idFactura);

        /// <summary>Imprime el comprobante del abono más reciente de una factura.</summary>
        void ImprimirAbono(decimal idxFactura, decimal idxUsuario);

        /// <summary>Imprime el recibo de una compra en la impresora configurada.</summary>
        void ImprimirCompra(decimal idCompra);

        /// <summary>Imprime el comprobante del abono de compra más reciente.</summary>
        void ImprimirAbonoCompra(decimal idxCompra, decimal idxUsuario);
    }
}
