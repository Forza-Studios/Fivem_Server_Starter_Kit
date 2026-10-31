(() => {
  const remote = document.getElementById('valve-remote');
  const status = remote.querySelector('.status'), error = remote.querySelector('.error');
  const led = remote.querySelector('.remote-led');
  const buttons = [...remote.querySelectorAll('[data-closed]')];
  let revision = 0, busy = false, closing = false, confirmationTimer, previousFocus;
  let motionRevision = 0, motionTimer;
  async function post(action, payload = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/${action}`, {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload), signal: AbortSignal.timeout(2500)
    });
    if (!response.ok) throw new Error('Sem resposta');
    return response.json();
  }
  function confirmedStatus() { return remote.dataset.closed==='true'?'Valve closed.':'Valve open.'; }
  function pending(value) {
    busy=value;
    remote.dataset.pending=String(value);
    remote.setAttribute('aria-busy',String(value));
    buttons.forEach(button=>button.disabled=value||closing);
    status.textContent=value?'Sending the command. Waiting for confirmation.':confirmedStatus();
    if(!value){clearTimeout(confirmationTimer);confirmationTimer=undefined;}
  }
  function completeMotion(phase) {
    if(remote.dataset.motion!==phase)return;
    clearTimeout(motionTimer);motionTimer=undefined;motionRevision++;
    remote.dataset.motion=phase==='entering'?'open':'hidden';
    if(phase==='exiting'){remote.hidden=true;closing=false;pending(false);}
  }
  function animate(phase) {
    clearTimeout(motionTimer);
    const mine=++motionRevision;
    remote.dataset.motion=phase;
    const duration=matchMedia('(prefers-reduced-motion: reduce)').matches?1:(phase==='entering'?300:200);
    // Complete even when CEF skips animationend (for example after losing visibility).
    motionTimer=setTimeout(()=>{if(motionRevision===mine)completeMotion(phase);},duration+40);
  }
  function hide() {
    if(remote.hidden||remote.dataset.motion==='exiting')return;
    closing=true;pending(false);
    led.classList.remove('is-sending');
    buttons.forEach(button=>button.classList.remove('is-pressing'));
    if(remote.contains(document.activeElement))document.activeElement.blur();
    if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});
    previousFocus=undefined;
    remote.inert=true;remote.setAttribute('aria-hidden','true');
    animate('exiting');
  }
  function show() {
    previousFocus=document.activeElement;
    remote.hidden=false;remote.inert=false;remote.removeAttribute('aria-hidden');
    animate('entering');remote.focus({preventScroll:true});
  }
  async function close() {
    if(closing||remote.hidden||remote.dataset.motion==='exiting')return;
    closing=true;
    const mine=++revision;
    pending(false);error.textContent='';
    try {
      const result=await post('valveClose');
      if(!result.ok)throw new Error('Recusado');
      if(revision===mine)hide();
    } catch { if(revision===mine){closing=false;pending(false);error.textContent='Could not close. Press ESC to try again.';} }
  }
  buttons.forEach(button=>button.addEventListener('click', async()=>{
    if (busy||closing||remote.hidden) return;
    button.classList.remove('is-pressing');
    led.classList.remove('is-sending');
    void button.offsetWidth;
    button.classList.add('is-pressing');
    led.classList.add('is-sending');
    const mine=++revision;pending(true);error.textContent='';
    try {
      const result=await post('valveSet',{closed:button.dataset.closed==='true'});
      if (!result.ok) throw new Error('Recusado');
      // State is only changed after the server acknowledgement, never optimistically.
      if(revision===mine)confirmationTimer=setTimeout(()=>{
        if(revision===mine){pending(false);error.textContent='No confirmation. Try again.';}
      },3000);
    } catch { if(revision===mine){pending(false);error.textContent='Could not change the valve.';} }
  }));
  buttons.forEach(button=>button.addEventListener('animationend',()=>button.classList.remove('is-pressing')));
  led.addEventListener('animationend',()=>led.classList.remove('is-sending'));
  remote.addEventListener('animationend',event=>{
    if(event.target!==remote)return;
    if(event.animationName==='valve-enter')completeMotion('entering');
    if(event.animationName==='valve-exit')completeMotion('exiting');
  });
  window.addEventListener('keydown',event=>{
    if(remote.hidden||remote.dataset.motion==='exiting')return;
    if(event.key==='Escape'){event.preventDefault();void close();}
    if(event.key==='Tab'){
      event.preventDefault();
      const available=buttons.filter(button=>!button.disabled);
      if(!available.length){remote.focus({preventScroll:true});return;}
      const index=available.indexOf(document.activeElement);
      const next=index<0?(event.shiftKey?available.length-1:0):(index+(event.shiftKey?-1:1)+available.length)%available.length;
      available[next].focus({preventScroll:true});
    }
  });
  window.addEventListener('message',({data})=>{
    if(!data||data.action!=='valve')return;
    const opening=remote.hidden||remote.dataset.motion==='exiting';
    revision++;error.textContent='';
    if(!data.open){hide();return;}
    closing=false;
    const closed=data.closed===true;remote.dataset.closed=String(closed);
    pending(false);
    buttons.forEach(button=>button.setAttribute('aria-pressed',String((button.dataset.closed==='true')===closed)));
    if(opening)show();
  });
})();
