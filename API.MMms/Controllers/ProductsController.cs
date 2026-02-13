using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using System.Data;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class ProductsController : ControllerBase
    {
        private readonly IProducts _context;
        private readonly IMapper _mapper;
        
        public ProductsController(IProducts context, IMapper mapper)
        {
                _context= context; 
            _mapper = mapper;
        }

        [HttpGet("SelectProductos")]
        public async Task<IActionResult> getProductos()
        {
            try
            {
                DataSet productoCategoria = new DataSet();

                productoCategoria =  _context.SelectProductos();
                return Ok(productoCategoria);
            }
            catch (Exception ex)
            {
                return Ok("Error: " + ex.Message);
            }
            
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            return NotFound();
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int Id)
        {
            return NotFound();
        }

        [HttpPost]
        public async Task<IActionResult> Save(ProductoDTOs dTOs)
        {
            var UWU = _context.Post(dTOs);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(ProductoDTOs OWO)
        {
            var UWU = _context.Update(OWO);
            return Ok(UWU);
        }

        [HttpDelete]
        public async Task<IActionResult> Eliminar(int Id)
        {
            return NotFound();
        }
    }
}
