// Shared promo engine: fixed 1200x675 stage, dark-galaxy background, perfect-loop clock.
// Each scene page sets window.SCENE = { dur, frame(t, api) } then calls window.__start().
(function(){
  const TAU = Math.PI*2;
  const stage = document.getElementById('stage'), wrap = document.getElementById('wrap');
  function fit(){ const k = Math.min(wrap.clientWidth/1200, wrap.clientHeight/675);
    stage.style.transform = `scale(${k})`;
    stage.style.left = (wrap.clientWidth-1200*k)/2+'px'; stage.style.top=(wrap.clientHeight-675*k)/2+'px'; }
  new ResizeObserver(fit).observe(wrap); fit();

  // inject galaxy bg at the back of the stage
  const bg = document.createElement('div'); bg.style.position='absolute'; bg.style.inset='0';
  bg.innerHTML = '<div class="neb a"></div><div class="neb b"></div><div class="neb c"></div>'
               + '<div class="starsFar"></div><div class="stars"></div>';
  stage.insertBefore(bg, stage.firstChild);
  const nebA=bg.querySelector('.neb.a'), nebB=bg.querySelector('.neb.b'), nebC=bg.querySelector('.neb.c');

  let seed = 20261117; const rnd = ()=>{ seed=(seed*1103515245+12345)&0x7fffffff; return seed/0x7fffffff; };
  function makeStars(host, count, big){
    const arr=[];
    for(let i=0;i<count;i++){
      const s=document.createElement('div'); s.className='star';
      const sz = big ? (rnd()>.75?3:2) : (rnd()>.9?2:1);
      s.style.width=s.style.height=sz+'px';
      s.style.left=(rnd()*1200)+'px'; s.style.top=(rnd()*675)+'px';
      const base = big ? 0.4+rnd()*0.5 : 0.14+rnd()*0.28;
      if (big && rnd()>0.68) s.classList.add('glow');
      host.appendChild(s);
      arr.push({ el:s, base, freq:(rnd()>.5?1:2), phase:rnd()*TAU });
    }
    return arr;
  }
  const allStars = makeStars(bg.querySelector('.stars'), 64, true)
          .concat(makeStars(bg.querySelector('.starsFar'), 80, false));

  const ease=(t,a,b)=>{ if(t<=a)return 0; if(t>=b)return 1; const x=(t-a)/(b-a); return x*x*x*(x*(x*6-15)+10); };
  const band=(t,a,b,c,d)=> ease(t,a,b) - ease(t,c,d);
  const api = { ease, band, TAU };

  function bgFrame(u){
    nebA.style.transform = `translate(${18*Math.sin(TAU*u)}px, ${14*Math.cos(TAU*u)}px)`;
    nebB.style.transform = `translate(${-16*Math.cos(TAU*u)}px, ${12*Math.sin(TAU*u)}px)`;
    nebC.style.transform = `translate(${12*Math.sin(TAU*u + 1.5)}px, ${-10*Math.cos(TAU*u)}px)`;
    for(const s of allStars){
      const o = s.base * (0.72 + 0.28*Math.sin(TAU*s.freq*u + s.phase));
      s.el.style.opacity = Math.max(0, Math.min(1, o)).toFixed(3);
    }
  }

  let t0=null, paused=false;
  function DUR(){ return (window.SCENE && window.SCENE.dur) || 13.5; }
  function tick(ts){
    if(t0==null)t0=ts;
    if(!paused){ const d=DUR(); const t=((ts-t0)/1000)%d; bgFrame(t/d); if(window.SCENE) window.SCENE.frame(t, api); }
    requestAnimationFrame(tick);
  }
  window.__start = ()=>{ requestAnimationFrame(tick); };
  window.__reset = ()=>{ t0=null; };
  window.__pause = (v)=>{ paused=v!==false; };
  window.__frameAt = (t)=>{ paused=true; const d=DUR(); bgFrame(t/d); if(window.SCENE) window.SCENE.frame(t, api); };
})();
