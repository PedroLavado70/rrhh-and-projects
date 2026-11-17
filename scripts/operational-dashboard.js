/* SIGRAL: tablero de decisiones diarias con datos vigentes de la aplicación. */
(function(){
'use strict';
const closed=new Set(['concluido','finalizado','terminado','cancelado','cerrado']);
function daysUntil(date,now=new Date()){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(String(date||'')))return null;
 const day=new Date(date+'T00:00:00');
 if(Number.isNaN(day.getTime()))return null;
 const base=new Date(now.getFullYear(),now.getMonth(),now.getDate());
 return Math.round((day-base)/86400000);
}
function evaluate(data,now=new Date()){
 const employees=data.employees||[],projects=data.projects||[],assignments=data.assignments||[];
 const activeProjects=projects.filter(p=>!closed.has(String(p.estado||'').toLowerCase().trim()));
 const due=activeProjects.map(p=>({...p,days:daysUntil(p.fecha_fin,now)}))
  .filter(p=>p.days!==null&&p.days<=60).sort((a,b)=>a.days-b.days);
 const activeEmps=employees.filter(e=>e.estado==='Activo');
 const expiring=activeEmps.filter(e=>String(e.tipo_contrato||'').trim().toLowerCase()!=='indefinido')
  .map(e=>({...e,days:daysUntil(e.fecha_fin_contrato,now)}))
  .filter(e=>e.days!==null&&e.days<=60).sort((a,b)=>a.days-b.days);
 const ending=assignments.map(a=>({...a,days:daysUntil(a.fecha_fin,now)}))
  .filter(a=>a.days!==null&&a.days>=0&&a.days<=30 &&
    activeProjects.some(p=>p.id===a.proyecto_id) &&
    activeEmps.some(e=>e.id===a.empleado_id))
  .sort((a,b)=>a.days-b.days);
 const projectById=new Map(projects.map(p=>[p.id,p]));
 const empById=new Map(employees.map(e=>[e.id,e]));
 return {due,expiring,ending,projectById,empById,daysUntil};
}
const node=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);if(cls)e.className=cls;return e};
function render(db){
 const place=document.getElementById('kpi-proy');if(!place)return;
 let section=document.getElementById('sigral-operational-alerts');
 if(!section){section=node('section',undefined,'card');section.id='sigral-operational-alerts';
 section.style.cssText='margin-top:14px;padding:15px 18px;';
 place.insertAdjacentElement('afterend',section);}
 section.replaceChildren();
 section.appendChild(node('h3','Próximos cierres y liberación de recursos'));
 const t=evaluate(db);
 const header=node('div',undefined);header.style.cssText='display:flex;flex-wrap:wrap;gap:10px;margin:12px 0';
 for(const [label,n] of [['Proyectos a cerrar (≤60 días)',t.due.length],
  ['Contratos con vencimiento (≤60 días)',t.expiring.length],
  ['Asignaciones que terminan (≤30 días)',t.ending.length]]){
  const box=node('div',undefined,'kpi');box.style.cssText='min-width:155px;flex:1;max-width:260px;';
  const num=node('strong',n);num.style.cssText='font-size:24px;display:block';
  box.append(num,node('span',label));header.append(box);
 }
 section.appendChild(header);
 const wrap=node('div',undefined);wrap.style.cssText='display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:14px;';
 const list=(heading,items,format)=>{
  const col=node('div');col.appendChild(node('h4',heading));
  if(!items.length){col.appendChild(node('p','Sin eventos próximos.'));return col}
  for(const item of items.slice(0,8)){const card=node('div',undefined,'res-card');card.style.margin='6px 0';
   const label=node('div',format(item));card.appendChild(label);
   const when=node('small',item.days<0?'Vencido hace '+(-item.days)+' días':'Termina en '+item.days+' días');
   when.style.color=item.days<=15?'#c2410c':'var(--t2)';card.appendChild(when);col.appendChild(card)}
  return col;
 };
 wrap.append(
  list('Proyectos próximos a terminar',t.due,p=>(p.codigo||'')+' — '+(p.nombre||'')),
  list('Contratos con vencimiento',t.expiring,e=>(e.apellidos||'')+', '+(e.nombres||'')+' — '+(e.cargo||'')),
  list('Asignaciones y recursos a liberar',t.ending,a=>{
   const emp=t.empById.get(a.empleado_id),p=t.projectById.get(a.proyecto_id);
   return (emp?emp.apellidos+', '+emp.nombres:'Recurso '+a.empleado_id)+' · '+(p?p.codigo:'Proyecto '+a.proyecto_id)+' · '+a.pct+'%';
  })
 );section.appendChild(wrap);
}
window.sigralOperational={daysUntil,evaluate,render};
})();