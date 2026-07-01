let currentPlantId = null;
let progressInterval = null;

window.addEventListener('message', function (event) {
    const data = event.data;

    switch (data.action) {
        case 'openPlantMenu':
            openMenu(data.plantData);
            break;
        case 'closeMenu':
            closeMenu();
            break;
        case 'showProgress':
            showProgress(data.title, data.duration);
            break;
        case 'hideProgress':
            hideProgress();
            break;
        case 'showPopup':
            showPopup(data.text, data.duration);
            break;
        case 'hidePopup':
            hidePopup();
            break;
        case 'openWaterMenu':
            openWaterMenu();
            break;
        case 'closeWaterMenu':
            closeWaterMenu();
            break;
    }
});

// ============================================
// PLANT STATUS MENU
// ============================================

function getPlantImage(type) {
    if (!type) return 'images/crop_default.png';
    const normalized = type.toLowerCase().trim();
    const mapping = {
        'alaskan ginseng': 'alaskan_ginseng.png',
        'pumpkin': 'pumpkin.png',
        'american ginseng': 'american_ginseng.png',
        'hop': 'hop.png',
        'pepper': 'pimenta.png',
        'black currant': 'black_currant.png',
        'blood flower': 'Blood_Flower.png',
        'choc daisy': 'Choc_Daisy.png',
        'coffee': 'coffeebeans.png',
        'creekplum': 'creekplum.png',
        'creeking thyme': 'Creeking_Thyme.png',
        'crows garlic': 'crows_garlic.png',
        'english mace': 'English_Mace.png',
        'tobacco': 'tobacco.png',
        'milk weed': 'milk_weed.png',
        'oleander sage': 'oleander_sage.png',
        'oregano': 'Oregano.png',
        'parasol mushroom': 'parasol_mushroom.png',
        'prairie poppy': 'prairie_poppy.png',
        'red raspberry': 'red_raspberry.png',
        'red sage': 'red_sage.png',
        'tea': 'tealeaf.png',
        'carrot': 'carrot.png',
        'wild mint': 'wild_mint.png',
        'wintergreen berry': 'wintergreen_berry.png',
        'yarrow': 'yarrow.png',
        'corn': 'corn.png',
        'apple': 'apple.png',
        'peach': 'consumable_peach.png',
        'cherry': 'cherry.png',
        'wheat': 'wheat.png',
        'lemon': 'lemon.png',
        'barley': 'barley.png',
        'banana': 'banana.png',
        'tomato': 'tomato.png',
        'lettuce': 'lettuce.png',
        'broccoli': 'broccoli.png',
        'sugar': 'cana.png',
        'agarita': 'agarita.png',
        'bay bolete': 'bay_bolete.png',
        'blackberry': 'blackberry.png',
        'evergreen huckleberry': 'evergreen_huckleberry.png',
        'strawberry': 'strawberry.png',
        'onion': 'onion.png',
        'artichoke': 'artichoke.png',
        'beans': 'beans.png',
        'beetroot': 'beetroot.png',
        'cabbage': 'cabbage.png',
        'celery': 'celery.png',
        'cucumber': 'cucumber.png',
        'grapes': 'grapes.png',
        'lime': 'lime.png',
        'mango': 'mango.png',
        'orange': 'orange.png',
        'pear': 'pear.png',
        'watermelon': 'watermelon.png',
        'peanuts': 'raw_peanuts.png',
        'rice': 'rice.png',
        'squash': 'squash.png'
    };
    const filename = mapping[normalized] || 'crop_default.png';
    return 'images/' + filename;
}

function openMenu(plantData) {
    currentPlantId = plantData.id;
    const menu = document.getElementById('plant-menu');

    // Update header
    document.getElementById('plant-title').textContent = 'Crop Status';
    document.getElementById('plant-type').textContent = plantData.type || 'Unknown';

    const plantImg = document.getElementById('plant-image');
    if (plantImg) {
        plantImg.src = getPlantImage(plantData.type);
    }

    // Update progress bars
    const waterPercent = plantData.water || 0;
    const growthPercent = plantData.growth || 0;

    document.getElementById('water-percent').textContent = waterPercent + '%';
    document.getElementById('water-bar').style.width = waterPercent + '%';

    document.getElementById('growth-percent').textContent = growthPercent + '%';
    document.getElementById('growth-bar').style.width = growthPercent + '%';

    const healthPercent = plantData.health || 0;
    // const weedPercent = plantData.weed || 0; // DISABLED

    document.getElementById('health-percent').textContent = healthPercent + '%';
    document.getElementById('health-bar').style.width = healthPercent + '%';

    // Disable Weeds Display
    // Disable Weeds Display
    const weedElem = document.getElementById('weed-percent');
    if (weedElem) {
        const weedContainer = weedElem.closest('.progress-item');
        if (weedContainer) {
            weedContainer.style.display = 'none';
        }
    }

    // Update info section
    if (plantData.timeRemaining) {
        document.getElementById('time-remaining').textContent = formatTime(plantData.timeRemaining);
    } else {
        document.getElementById('time-remaining').textContent = '--:--';
    }

    // Status text precedence
    let statusText = 'Growing...';

    if (growthPercent >= 100) {
        statusText = 'Ready to Harvest!';
    } else if (healthPercent < 40) {
        statusText = 'Unhealthy!';
        // } else if (weedPercent > 0) {
        //    statusText = 'Weeds Growing!';
    } else if (waterPercent < 20) {
        statusText = 'Needs Water!';
    } else if (waterPercent < 100) {
        statusText = 'Growing...';
    }
    document.getElementById('plant-status').textContent = statusText;

    // Build action buttons
    buildActionButtons(plantData);

    // Show menu
    menu.classList.remove('hidden');
}

function formatTime(seconds) {
    if (seconds <= 0) return 'Ready!';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
}

function buildActionButtons(plantData) {
    const grid = document.getElementById('actions-grid');
    grid.innerHTML = '';

    const waterPercent = plantData.water || 0;
    const growthPercent = plantData.growth || 0;
    const weedPercent = plantData.weed || 0;

    // Water button - show if needs water
    if (waterPercent < 100) {
        const waterBtn = createActionButton('💧', 'Water', 'water', false);
        grid.appendChild(waterBtn);
    }

    // Remove Weeds button - DISABLED
    /*
    if (weedPercent > 0) {
        const weedBtn = createActionButton('🌿', 'Remove Weeds', 'removeWeeds', false);
        grid.appendChild(weedBtn);
    }
    */

    // Fertilize button - show if not fertilized
    if (!plantData.fertilized) {
        const fertBtn = createActionButton('💩', 'Fertilize', 'fertilize', false);
        grid.appendChild(fertBtn);
    }

    // Harvest button - only when fully grown
    if (growthPercent >= 100) {
        const harvestBtn = createActionButton('🌾', 'Harvest', 'harvest', false, 'harvest');
        grid.appendChild(harvestBtn);
    }

    // Destroy button - always available
    const destroyBtn = createActionButton('🗑️', 'Destroy', 'destroy', false, 'destroy');
    grid.appendChild(destroyBtn);
}

function createActionButton(icon, label, action, disabled, extraClass = '') {
    const btn = document.createElement('button');
    btn.className = 'action-btn' + (disabled ? ' disabled' : '') + (extraClass ? ' ' + extraClass : '');
    btn.innerHTML = `
        <span class="icon">${icon}</span>
        <span>${label}</span>
    `;

    if (!disabled) {
        btn.onclick = () => performAction(action);
    }

    return btn;
}

function performAction(action) {
    fetch(`https://devchacha-farming/plantAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: action,
            plantId: currentPlantId
        })
    }).catch(error => console.error('Action error:', error));

    // Close menu for harvest/destroy
    if (action === 'harvest' || action === 'destroy') {
        setTimeout(() => closeMenu(), 100);
    } else {
        // For water, close menu to show animation
        closeMenu();
    }
}

function closeMenu() {
    const menu = document.getElementById('plant-menu');
    if (menu) {
        menu.classList.add('hidden');
    }
    currentPlantId = null;

    fetch(`https://devchacha-farming/closeMenu`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(error => { });
}

// ============================================
// PROGRESS BAR
// ============================================

function showProgress(title, duration) {
    const overlay = document.getElementById('progress-overlay');
    const titleEl = document.getElementById('progress-title');
    const barEl = document.getElementById('progress-bar-inner');
    const percentEl = document.getElementById('progress-percentage');

    titleEl.textContent = title || 'Working...';
    barEl.style.width = '0%';
    percentEl.textContent = '0%';

    overlay.classList.remove('hidden');

    // Animate progress
    const startTime = Date.now();
    const durationMs = duration || 5000;

    if (progressInterval) {
        clearInterval(progressInterval);
    }

    progressInterval = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min((elapsed / durationMs) * 100, 100);

        barEl.style.width = progress + '%';
        percentEl.textContent = Math.floor(progress) + '%';

        if (progress >= 100) {
            clearInterval(progressInterval);
            progressInterval = null;
            setTimeout(() => hideProgress(), 300);
        }
    }, 50);
}

function hideProgress() {
    if (progressInterval) {
        clearInterval(progressInterval);
        progressInterval = null;
    }
    const overlay = document.getElementById('progress-overlay');
    if (overlay) {
        overlay.classList.add('hidden');
    }
}

// ============================================
// TEXT POPUP
// ============================================

function showPopup(text, duration) {
    const popup = document.getElementById('text-popup');
    const content = document.getElementById('popup-content');

    content.textContent = text || 'Working...';
    popup.classList.remove('hidden');

    if (duration && duration > 0) {
        setTimeout(() => hidePopup(), duration);
    }
}

function hidePopup() {
    const popup = document.getElementById('text-popup');
    if (popup) {
        popup.classList.add('hidden');
    }
}

// Close on ESC key
document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') {
        closeMenu();
        hideProgress();
        hidePopup();
        closeWaterMenu();
    }
});

// ============================================
// WATER MENU
// ============================================

function openWaterMenu() {
    const menu = document.getElementById('water-menu');
    menu.classList.remove('hidden');
}

function closeWaterMenu() {
    const menu = document.getElementById('water-menu');
    if (menu) {
        menu.classList.add('hidden');
    }

    fetch(`https://devchacha-farming/closeWaterMenu`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(error => { });
}

function waterAction(action) {
    fetch(`https://devchacha-farming/waterAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: action
        })
    }).catch(error => console.error('Water action error:', error));

    closeWaterMenu();
}

