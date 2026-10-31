(() => {
  const config = window.RAUL_SITE_CONFIG || {};
  const menuToggle = document.querySelector('.menu-toggle');
  const nav = document.querySelector('.main-nav');
  menuToggle?.addEventListener('click', () => {
    const open = menuToggle.getAttribute('aria-expanded') !== 'true';
    menuToggle.setAttribute('aria-expanded', String(open));
    menuToggle.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
    nav.classList.toggle('is-open', open);
  });
  nav?.querySelectorAll('a').forEach(link => link.addEventListener('click', () => {
    nav.classList.remove('is-open'); menuToggle?.setAttribute('aria-expanded', 'false'); menuToggle?.setAttribute('aria-label', 'Abrir menu');
  }));
  document.getElementById('year').textContent = new Date().getFullYear();
  const dateInput = document.getElementById('date');
  if (dateInput) {
    const today = new Date();
    dateInput.min = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
  }
  const whatsappNumber = String(config.whatsappNumber || '558585962829').replace(/\D/g, '');
  const openWhatsApp = message => {
    const url = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(message)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  };
  // CTAs de aula abrem diretamente uma conversa no WhatsApp do Raul.
  document.querySelectorAll('a[href="#agendar"]').forEach(link => {
    const label = (link.textContent || '').replace(/\s+/g, ' ').trim();
    link.href = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent('Olá, Raul! Tenho interesse em fazer uma aula de kitesurf. Gostaria de saber mais informações e consultar a disponibilidade.')}`;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    link.removeAttribute('href');
    link.href = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent('Olá, Raul! Tenho interesse em fazer uma aula de kitesurf. Gostaria de saber mais informações e consultar a disponibilidade.')}`;
  });
  document.querySelectorAll('.choose-lesson').forEach(button => button.addEventListener('click', () => {
    const lessonName = button.dataset.lesson || 'Aula de kitesurf';
    openWhatsApp(`Olá, Raul! Tenho interesse em ${lessonName.toLowerCase()}. Gostaria de saber mais informações e consultar a disponibilidade.`);
  }));
  const form = document.getElementById('booking-form');
  const status = document.getElementById('form-status');
  form?.addEventListener('submit', event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const number = String(config.whatsappNumber || '').replace(/\D/g, '');
    if (!number) {
      status.textContent = 'O formulário está pronto, mas falta configurar o número oficial do WhatsApp do Raul em config.js. Nenhuma mensagem foi enviada. Entre em contato com o responsável pelo site para concluir essa configuração.';
      status.classList.add('is-error');
      return;
    }
    const data = new FormData(form);
    const value = key => String(data.get(key) || '').trim() || 'Não informado';
    const message = [
      `Olá, ${config.instructorName || 'Raul'}! Tenho interesse em agendar uma aula de kitesurf.`, '',
      `Nome: ${value('name')}`,
      `WhatsApp: ${value('phone')}`,
      `Tipo de aula: ${value('lesson')}`,
      `Data desejada: ${value('date')}`,
      `Horário desejado: ${value('time')}`,
      `Nível de experiência: ${value('level')}`,
      `Observações: ${value('notes')}`, '',
      'Gostaria de confirmar sua disponibilidade e receber mais informações sobre valores e próximos passos.'
    ].join('\n');
    const url = `https://wa.me/${number}?text=${encodeURIComponent(message)}`;
    const opened = window.open(url, '_blank', 'noopener,noreferrer');
    if (opened) { status.textContent = 'O WhatsApp foi aberto com sua solicitação. A aula ainda depende da confirmação de Raul.'; status.classList.remove('is-error'); }
    else { status.textContent = 'Não foi possível abrir o WhatsApp automaticamente. Verifique se o navegador bloqueou a nova janela e tente novamente.'; status.classList.add('is-error'); }
  });
})();
