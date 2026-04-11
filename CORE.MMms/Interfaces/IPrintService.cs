namespace CORE.MMms.Interfaces
{
    public interface IPrintService
    {
        /// <summary>Imprime el recibo de una venta en la impresora configurada.</summary>
        void ImprimirFactura(decimal idFactura);

        /// <summary>Imprime el comprobante del abono más reciente de una factura.</summary>
        void ImprimirAbono(decimal idxFactura, decimal idxUsuario);
    }
}
