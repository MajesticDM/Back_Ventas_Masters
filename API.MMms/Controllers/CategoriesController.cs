using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class CategoriesController : ControllerBase
    {
        private readonly ICategories _context;
        private readonly IMapper _mapper;
        public CategoriesController(ICategories context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var MMDS = await _context.GetCategories();
            var MMD = _mapper.Map<IEnumerable<CategoriaDTOs>>(MMDS);
            return Ok(MMD);
        }

        [HttpGet("GetCategorias")]
        public async Task<IActionResult> GetCategorias()
        {
            var categorias = _context.CargarCategorias();
            return Ok(categorias);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int Id)
        {
            var UWU = await _context.GetxId(Id);
            if (UWU == null)
            {
                return Ok(UWU);
            }
            else
            {
                var OWO = _mapper.Map<CategoriaDTOs>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(CategoriaDTOs dTOs)
        {
            CategoriaDTOs ct = new CategoriaDTOs();

            ct.Categoria1 = dTOs.Categoria1;
            ct.Estados = dTOs.Estados;

            var UWU = _mapper.Map<Categoria>(ct);
            await _context.Post(UWU);
            return Ok(UWU);
        }

        [HttpPut]
        public async Task<IActionResult> Actualizar(CategoriaDTOs OWO)
        {
            var UWU = _mapper.Map<Categoria>(OWO);
            UWU.CategoriaId = OWO.CategoriaId;
            await _context.Update(UWU);
            return Ok(UWU);
        }

        [HttpDelete]
        public async Task<IActionResult> Eliminar(int Id)
        {
            var UWU = await _context.Delete(Id);
            return Ok(UWU);
        }
    }
}
