// Hero mock: a fake countdown that "gets skipped" on a loop, illustrating
// what NoWait does to a shortener's wait screen.
(function heroDemo() {
    const countdownEl = document.getElementById('heroCountdown');
    const waitEl = document.querySelector('.demo-mock-wait');
    const progressEl = document.getElementById('heroProgress');
    if (!countdownEl || !waitEl || !progressEl) return;

    function run() {
        let n = 5;
        countdownEl.textContent = n;
        waitEl.classList.remove('done');
        progressEl.style.transition = 'none';
        progressEl.style.width = '0%';
        void progressEl.offsetWidth; // restart the CSS transition
        progressEl.style.transition = 'width 0.35s ease';
        progressEl.style.width = '100%';

        setTimeout(() => {
            waitEl.textContent = 'Skipped by NoWait ✓';
            waitEl.classList.add('done');
            setTimeout(run, 2200);
        }, 450);
    }
    run();
})();

// "Without / With NoWait" comparison tabs.
(function comparisonDemo() {
    const tabs = document.querySelectorAll('.tool-tabs .tab-btn');
    const panels = {
        without: document.getElementById('without-content'),
        with: document.getElementById('with-content'),
    };
    if (!tabs.length) return;

    tabs.forEach((tab) => {
        tab.addEventListener('click', () => {
            tabs.forEach((t) => t.classList.remove('active'));
            tab.classList.add('active');
            Object.values(panels).forEach((p) => p && p.classList.remove('active'));
            const target = panels[tab.dataset.tool];
            if (target) target.classList.add('active');
        });
    });

    const fill = document.getElementById('withoutFill');
    const label = document.getElementById('withoutLabel');
    function playWithout() {
        if (!fill || !label) return;
        fill.style.transition = 'none';
        fill.style.width = '0%';
        void fill.offsetWidth;
        let secs = 5;
        label.textContent = `Waiting… ${secs}s`;
        fill.style.transition = 'width 5s linear';
        fill.style.width = '100%';
        const t = setInterval(() => {
            secs -= 1;
            if (secs <= 0) {
                label.textContent = 'Continue →';
                clearInterval(t);
            } else {
                label.textContent = `Waiting… ${secs}s`;
            }
        }, 1000);
    }
    playWithout();

    const replayBtn = document.getElementById('replayDemo');
    if (replayBtn) {
        replayBtn.addEventListener('click', () => {
            const display = document.getElementById('withDisplay');
            if (!display) return;
            display.textContent = '…';
            setTimeout(() => { display.textContent = 'Redirecting instantly…'; }, 150);
        });
    }

    document.querySelector('[data-tool="without"]')?.addEventListener('click', playWithout);
})();

// Hamburger menu (mobile nav) -- same behavior as the other project microsites.
(function nav() {
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');
    if (!hamburger || !navMenu) return;
    hamburger.addEventListener('click', () => {
        const isOpen = navMenu.classList.toggle('mobile-open');
        hamburger.setAttribute('aria-expanded', isOpen);
    });
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.nav-container') && navMenu.classList.contains('mobile-open')) {
            navMenu.classList.remove('mobile-open');
            hamburger.setAttribute('aria-expanded', 'false');
        }
    });
    navMenu.querySelectorAll('a').forEach((a) => {
        a.addEventListener('click', () => {
            navMenu.classList.remove('mobile-open');
            hamburger.setAttribute('aria-expanded', 'false');
        });
    });
})();
