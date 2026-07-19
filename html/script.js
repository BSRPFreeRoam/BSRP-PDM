const app = document.getElementById('app');
const catsEl = document.getElementById('categories');
const listEl = document.getElementById('vehicleList');
const sectionTitle = document.getElementById('sectionTitle');
const shopNameEl = document.getElementById('shopName');
const subtitleEl = document.getElementById('subtitle');
const searchEl = document.getElementById('search');
const colorsEl = document.getElementById('colors');

let state = null;
let activeCat = null;
let activeModel = null;
let searchQ = '';
let isFree = true;

const COLORS = [
    [255, 255, 255],
    [0, 0, 0],
    [220, 20, 60],
    [255, 140, 0],
    [255, 215, 0],
    [50, 205, 50],
    [0, 191, 255],
    [30, 144, 255],
    [138, 43, 226],
    [255, 20, 147],
    [0, 229, 255],
    [124, 92, 255]
];

function resourceName() {
    try {
        if (typeof GetParentResourceName === 'function') return GetParentResourceName();
    } catch (e) {}
    return 'bsrp-pdm';
}

function post(name, data) {
    return fetch('https://' + resourceName() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).then(function (r) {
        return r.json().catch(function () { return {}; });
    }).catch(function () { return {}; });
}

function money(n) {
    if (isFree) return 'FREE';
    try {
        return '$' + Number(n || 0).toLocaleString();
    } catch (e) {
        return '$' + (n || 0);
    }
}

function renderColors() {
    colorsEl.innerHTML = '';
    COLORS.forEach(function (c, i) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'swatch' + (i === 0 ? ' active' : '');
        btn.style.background = 'rgb(' + c[0] + ',' + c[1] + ',' + c[2] + ')';
        btn.addEventListener('click', function () {
            colorsEl.querySelectorAll('.swatch').forEach(function (el) {
                el.classList.remove('active');
            });
            btn.classList.add('active');
            post('color', { r: c[0], g: c[1], b: c[2] });
        });
        colorsEl.appendChild(btn);
    });
}

function renderCategories() {
    catsEl.innerHTML = '';
    if (!state || !state.categories) return;
    state.categories.forEach(function (cat) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'cat-btn' + (activeCat === cat.key ? ' active' : '');
        btn.innerHTML =
            '<span>' + cat.label + '</span>' +
            '<span class="cat-count">' + (cat.count || 0) + '</span>';
        btn.addEventListener('click', function () {
            activeCat = cat.key;
            renderCategories();
            renderList();
        });
        catsEl.appendChild(btn);
    });
}

function renderList() {
    listEl.innerHTML = '';
    if (!activeCat || !state || !state.vehicles) {
        listEl.innerHTML = '<div class="empty-hint">Choose a category on the left.</div>';
        sectionTitle.textContent = 'Select a class';
        return;
    }

    sectionTitle.textContent = activeCat;
    let list = state.vehicles[activeCat] || [];
    if (searchQ) {
        const q = searchQ.toLowerCase();
        list = list.filter(function (v) {
            return (v.name || '').toLowerCase().indexOf(q) !== -1
                || (v.model || '').toLowerCase().indexOf(q) !== -1;
        });
    }

    if (!list.length) {
        listEl.innerHTML = '<div class="empty-hint">No vehicles match.</div>';
        return;
    }

    // sort by price desc
    list = list.slice().sort(function (a, b) {
        return (b.price || 0) - (a.price || 0);
    });

    list.forEach(function (v) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'veh-item' + (activeModel === v.model ? ' active' : '');
        row.innerHTML =
            '<span class="name">' + (v.name || v.model) + '</span>' +
            '<span class="meta"><span>' + (v.stat || '—') + ' · ' + v.model + '</span><b>' + money(v.price) + '</b></span>';
        row.addEventListener('click', function () {
            selectVehicle(v);
        });
        listEl.appendChild(row);
    });
}

function setStats(stats) {
    stats = stats || {};
    document.getElementById('stEngine').textContent = stats.engine || '—';
    document.getElementById('stBrakes').textContent = stats.brakes || '—';
    document.getElementById('stSusp').textContent = stats.suspension || '—';
    document.getElementById('stTrans').textContent = stats.transmission || '—';
    document.getElementById('stArmor').textContent = stats.armor || '—';
    document.getElementById('stSeats').textContent = stats.seats != null ? stats.seats : '—';
}

function selectVehicle(v) {
    activeModel = v.model;
    document.getElementById('vehTitle').textContent = v.name || v.model;
    document.getElementById('vehModel').textContent = v.model;
    document.getElementById('priceVal').textContent = money(v.price);
    renderList();
    post('select', {
        model: v.model,
        name: v.name,
        price: v.price
    }).then(function (res) {
        if (res && res.ok) {
            setStats(res.stats);
        }
    });
}

function openUi(data) {
    state = data || {};
    isFree = state.free !== false;
    activeCat = null;
    activeModel = null;
    searchQ = '';
    searchEl.value = '';
    shopNameEl.textContent = state.shopName || 'PDM';
    subtitleEl.textContent = state.subtitle || 'SHOWROOM';
    setStats({});
    document.getElementById('vehTitle').textContent = 'No vehicle';
    document.getElementById('vehModel').textContent = '—';
    document.getElementById('priceVal').textContent = isFree ? 'FREE' : '—';
    app.classList.remove('hidden');
    renderCategories();
    renderList();
    renderColors();

    // auto-select first category
    if (state.categories && state.categories.length) {
        activeCat = state.categories[0].key;
        renderCategories();
        renderList();
    }
}

function closeUi() {
    app.classList.add('hidden');
    state = null;
    post('close', {});
}

document.getElementById('btnClose').addEventListener('click', closeUi);
document.getElementById('btnClaim').addEventListener('click', function () {
    if (!activeModel) return;
    post('claim', {});
});
document.getElementById('btnTest').addEventListener('click', function () {
    if (!activeModel) return;
    post('testDrive', {});
});
document.getElementById('btnSpin').addEventListener('click', function () {
    post('spin', {}).then(function (res) {
        document.getElementById('btnSpin').classList.toggle('active', !!(res && res.spinning));
    });
});
document.getElementById('btnZoomIn').addEventListener('click', function () {
    post('zoom', { dir: 'in' });
});
document.getElementById('btnZoomOut').addEventListener('click', function () {
    post('zoom', { dir: 'out' });
});

searchEl.addEventListener('input', function () {
    searchQ = (searchEl.value || '').trim();
    renderList();
});
searchEl.addEventListener('keydown', function (e) {
    e.stopPropagation();
});

window.addEventListener('message', function (event) {
    const msg = event.data || {};
    if (msg.action === 'open') {
        openUi(msg.data);
    } else if (msg.action === 'close' || msg.action === 'hide') {
        app.classList.add('hidden');
    } else if (msg.action === 'resume') {
        app.classList.remove('hidden');
    }
});

document.addEventListener('keydown', function (e) {
    if (app.classList.contains('hidden')) return;
    if (e.key === 'Escape') {
        const tag = (document.activeElement && document.activeElement.tagName) || '';
        if (tag === 'INPUT') return;
        closeUi();
    }
});
