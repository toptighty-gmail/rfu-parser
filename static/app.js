document.addEventListener('DOMContentLoaded', () => {
    const tabBtns = document.querySelectorAll('.tab-btn');
    const standingsSection = document.getElementById('standings-section');
    const fixturesSection = document.getElementById('fixtures-section');
    const searchInput = document.getElementById('search-input');
    const subTabBtns = document.querySelectorAll('.sub-tab-btn');

    let activeFilter = 'all'; // 'all', 'completed', 'upcoming'

    // Tab Switching (Standings vs Fixtures) with LocalStorage persistence
    function activateTab(target) {
        tabBtns.forEach(b => {
            if (b.dataset.tab === target) {
                b.classList.add('active');
            } else {
                b.classList.remove('active');
            }
        });

        if (target === 'standings') {
            if (standingsSection) standingsSection.classList.remove('hidden');
            if (fixturesSection) fixturesSection.classList.add('hidden');
        } else if (target === 'fixtures') {
            if (standingsSection) standingsSection.classList.add('hidden');
            if (fixturesSection) fixturesSection.classList.remove('hidden');
        }
        localStorage.setItem('rfu_active_tab', target);
    }

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            activateTab(btn.dataset.tab);
        });
    });

    // On page load, restore saved active tab if set to 'fixtures' or if hash is #fixtures
    const savedActiveTab = localStorage.getItem('rfu_active_tab');
    if (window.location.hash === '#fixtures' || savedActiveTab === 'fixtures') {
        activateTab('fixtures');
    }

    // Sub-tab switching for Fixtures & Results filtering
    subTabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            subTabBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            // Set styles dynamically for clean active state
            subTabBtns.forEach(b => {
                if (b === btn) {
                    b.style.backgroundColor = 'var(--accent-gold)';
                    b.style.color = '#0f172a';
                } else {
                    b.style.backgroundColor = 'transparent';
                    b.style.color = 'var(--text-secondary)';
                }
            });

            activeFilter = btn.dataset.filter;
            applyFilters();
        });
    });

    const teamInput = document.getElementById('team-input');
    const spotlightTeam = teamInput ? teamInput.value.trim() : '';
    let showOnlySpotlightFixtures = true;

    function applyFilters() {
        const query = searchInput ? searchInput.value.toLowerCase().trim() : '';
        const tokens = query.split(/\s+/).filter(t => t.length > 1);

        // 1. Filter Standings Table Rows
        const rows = document.querySelectorAll('#standings-body tr');
        rows.forEach(row => {
            const teamName = row.dataset.team ? row.dataset.team.toLowerCase() : '';
            let matchesQuery = true;
            if (tokens.length > 0) {
                matchesQuery = tokens.every(token => teamName.indexOf(token) !== -1);
            }
            if (matchesQuery) {
                row.classList.remove('js-hidden');
            } else {
                row.classList.add('js-hidden');
            }
        });

        // 2. Filter Fixture Cards
        const cards = document.querySelectorAll('.fixture-card');
        const spotlightTokens = spotlightTeam.toLowerCase().split(/\s+/).filter(t => t.length > 1);

        cards.forEach(card => {
            const home = card.dataset.home ? card.dataset.home.toLowerCase() : '';
            const away = card.dataset.away ? card.dataset.away.toLowerCase() : '';
            const status = card.dataset.status ? card.dataset.status.toLowerCase() : '';

            // A. Check spotlight filter if enabled
            let matchesSpotlight = true;
            if (showOnlySpotlightFixtures && spotlightTokens.length > 0) {
                const matchesHome = spotlightTokens.every(token => home.indexOf(token) !== -1);
                const matchesAway = spotlightTokens.every(token => away.indexOf(token) !== -1);
                matchesSpotlight = matchesHome || matchesAway;
            }

            // B. Check ad-hoc search filter query (if user typed in #search-input)
            let matchesQuery = true;
            if (tokens.length > 0) {
                const matchesHome = tokens.every(token => home.indexOf(token) !== -1);
                const matchesAway = tokens.every(token => away.indexOf(token) !== -1);
                matchesQuery = matchesHome || matchesAway;
            }

            // C. Check status filter
            let matchesStatus = true;
            if (activeFilter === 'completed') {
                matchesStatus = status === 'completed';
            } else if (activeFilter === 'upcoming') {
                matchesStatus = status === 'scheduled';
            }

            if (matchesSpotlight && matchesQuery && matchesStatus) {
                card.classList.remove('js-hidden');
            } else {
                card.classList.add('js-hidden');
            }
        });

        // 3. Handle Round Group Layout and Header visibility
        const roundGroups = document.querySelectorAll('.round-group');
        roundGroups.forEach(group => {
            // Count cards inside this group that are visible
            const visibleCards = Array.from(group.querySelectorAll('.fixture-card')).filter(c => !c.classList.contains('js-hidden'));
            const roundTitle = group.querySelector('.round-title');

            if (visibleCards.length === 0) {
                group.classList.add('js-hidden');
            } else {
                group.classList.remove('js-hidden');
                // Hide round headers if a search query is active
                if (query !== '') {
                    if (roundTitle) roundTitle.classList.add('js-hidden');
                } else {
                    if (roundTitle) roundTitle.classList.remove('js-hidden');
                }
            }
        });
    }

    // Autocomplete Suggestions logic
    const suggestionsUl = document.getElementById('team-suggestions');
    let debounceTimer;

    if (teamInput && suggestionsUl) {
        teamInput.addEventListener('keyup', (e) => {
            // Ignore arrow keys, enter, escape
            if ([37, 38, 39, 40, 13, 27].indexOf(e.keyCode) !== -1) return;

            clearTimeout(debounceTimer);
            const val = teamInput.value.trim();

            if (val.length < 3) {
                suggestionsUl.innerHTML = '';
                suggestionsUl.style.display = 'none';
                return;
            }

            // Debounce API calls to avoid spamming the backend
            debounceTimer = setTimeout(() => {
                fetch(`/api/suggest-teams?q=${encodeURIComponent(val)}`)
                    .then(response => response.json())
                    .then(res => {
                        const items = res.data || [];
                        suggestionsUl.innerHTML = '';
                        
                        if (items.length === 0) {
                            suggestionsUl.style.display = 'none';
                            return;
                        }

                        items.forEach(item => {
                            const li = document.createElement('li');
                            li.textContent = item.name;
                            li.dataset.id = item._id;
                            li.addEventListener('click', () => {
                                teamInput.value = item.name;
                                suggestionsUl.innerHTML = '';
                                suggestionsUl.style.display = 'none';
                            });
                            suggestionsUl.appendChild(li);
                        });
                        suggestionsUl.style.display = 'block';
                    })
                    .catch(err => {
                        console.error('Error fetching suggestions:', err);
                    });
            }, 750);
        });

        // Hide suggestions when clicking outside the container
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.team-search-container')) {
                suggestionsUl.style.display = 'none';
            }
        });
    }

    // Toggle spotlight fixtures
    const toggleBtn = document.getElementById('toggle-team-fixtures');
    if (toggleBtn && spotlightTeam) {
        toggleBtn.addEventListener('click', () => {
            showOnlySpotlightFixtures = !showOnlySpotlightFixtures;
            if (showOnlySpotlightFixtures) {
                toggleBtn.textContent = 'Show All Fixtures';
                toggleBtn.style.borderColor = 'var(--accent-gold)';
                toggleBtn.style.color = 'var(--accent-gold)';
                toggleBtn.style.background = 'transparent';
            } else {
                toggleBtn.textContent = `Show ${spotlightTeam} Only`;
                toggleBtn.style.borderColor = 'var(--bg-card-border)';
                toggleBtn.style.color = 'var(--text-secondary)';
                toggleBtn.style.background = 'rgba(255, 255, 255, 0.05)';
            }
            applyFilters();
        });
    }

    // Bind real-time input event for live filter
    if (searchInput) {
        searchInput.addEventListener('input', applyFilters);
    }

    // Dynamic Print Stylesheets Injection for page sizes
    const printA4Btn = document.getElementById('print-a4-btn');

    function cleanupPrintStyles() {
        const style = document.getElementById('print-page-style');
        if (style) style.remove();
        document.body.classList.remove('print-mode-a4');
    }

    window.addEventListener('afterprint', cleanupPrintStyles);

    if (printA4Btn) {
        printA4Btn.addEventListener('click', () => {
            cleanupPrintStyles();
            const style = document.createElement('style');
            style.id = 'print-page-style';
            style.innerHTML = `
                @page {
                    size: A4 portrait !important;
                    margin: 0 !important;
                }
            `;
            document.head.appendChild(style);
            document.body.classList.add('print-mode-a4');
            setTimeout(() => {
                window.print();
            }, 100);
        });
    }

    // Toggle Form Column visibility
    const toggleFormBtn = document.getElementById('toggle-form-btn');
    const toggleFormText = document.getElementById('toggle-form-text');
    const toggleFormIcon = document.getElementById('toggle-form-icon');

    // Initialize state from localStorage
    const isFormHidden = localStorage.getItem('hideFormColumn') === 'true';
    if (isFormHidden) {
        document.body.classList.add('hide-form-column');
        if (toggleFormText) toggleFormText.textContent = 'Show Form Column';
        if (toggleFormIcon) toggleFormIcon.textContent = '🙈';
    }

    if (toggleFormBtn) {
        toggleFormBtn.addEventListener('click', () => {
            const hidden = document.body.classList.toggle('hide-form-column');
            localStorage.setItem('hideFormColumn', hidden);
            if (toggleFormText) {
                toggleFormText.textContent = hidden ? 'Show Form Column' : 'Hide Form Column';
            }
            if (toggleFormIcon) {
                toggleFormIcon.textContent = hidden ? '🙈' : '👁️';
            }
        });
    }

    // Run initial filter immediately on load
    applyFilters();

    // Admin Login Modal Handlers
    const adminLoginBtn = document.getElementById('admin-login-btn');
    const adminLogoutBtn = document.getElementById('admin-logout-btn');
    const adminLoginModal = document.getElementById('admin-login-modal');
    const adminLoginForm = document.getElementById('admin-login-form');
    const adminLoginError = document.getElementById('admin-login-error');

    if (adminLoginBtn && adminLoginModal) {
        adminLoginBtn.addEventListener('click', () => {
            adminLoginModal.classList.remove('hidden');
            const pwdInput = document.getElementById('admin-password-input');
            if (pwdInput) pwdInput.focus();
        });
    }

    if (adminLogoutBtn) {
        adminLogoutBtn.addEventListener('click', () => {
            fetch('/api/admin/logout', { method: 'POST' })
                .then(r => r.json())
                .then(() => window.location.reload());
        });
    }

    if (adminLoginForm) {
        adminLoginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const password = document.getElementById('admin-password-input').value;
            fetch('/api/admin/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password })
            })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    window.location.reload();
                } else {
                    if (adminLoginError) {
                        adminLoginError.textContent = res.error || 'Invalid password.';
                        adminLoginError.style.display = 'block';
                    }
                }
            })
            .catch(err => console.error(err));
        });
    }

    // Modal close buttons (cancel / cross)
    document.querySelectorAll('.close-modal-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            if (adminLoginModal) adminLoginModal.classList.add('hidden');
            const customModal = document.getElementById('custom-fixture-modal');
            if (customModal) customModal.classList.add('hidden');
        });
    });

    // Close modal when clicking on dark overlay backdrop
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                overlay.classList.add('hidden');
            }
        });
    });

    // Custom Fixture Modal Handlers
    const openAddFixtureBtn = document.getElementById('open-add-fixture-modal-btn');
    const customFixtureModal = document.getElementById('custom-fixture-modal');
    const customFixtureForm = document.getElementById('custom-fixture-form');
    const modalTitle = document.getElementById('custom-fixture-modal-title');

    if (openAddFixtureBtn && customFixtureModal) {
        openAddFixtureBtn.addEventListener('click', () => {
            if (modalTitle) modalTitle.textContent = '➕ Add Manual / Friendly Fixture';
            if (customFixtureForm) customFixtureForm.reset();
            document.getElementById('cf-id').value = '';
            
            // Default date to today YYYY-MM-DD
            const today = new Date().toISOString().split('T')[0];
            const dateInput = document.getElementById('cf-date');
            if (dateInput) dateInput.value = today;

            customFixtureModal.classList.remove('hidden');
        });
    }

    if (customFixtureForm) {
        customFixtureForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const fixId = document.getElementById('cf-id').value;
            const payload = {
                date: document.getElementById('cf-date').value,
                time: document.getElementById('cf-time').value,
                home_team: document.getElementById('cf-home').value,
                away_team: document.getElementById('cf-away').value,
                home_score: document.getElementById('cf-home-score').value !== '' ? parseInt(document.getElementById('cf-home-score').value) : null,
                away_score: document.getElementById('cf-away-score').value !== '' ? parseInt(document.getElementById('cf-away-score').value) : null,
                venue: document.getElementById('cf-venue').value,
                season: document.getElementById('cf-season').value
            };

            const url = fixId ? `/api/fixtures/custom/${fixId}` : '/api/fixtures/custom';
            const method = fixId ? 'PUT' : 'POST';

            fetch(url, {
                method: method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    localStorage.setItem('rfu_active_tab', 'fixtures');
                    window.location.hash = 'fixtures';
                    window.location.reload();
                } else {
                    alert(res.error || 'Failed to save custom fixture.');
                }
            })
            .catch(err => console.error(err));
        });
    }

    // Edit Custom Fixture
    document.querySelectorAll('.btn-edit-cf').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            if (modalTitle) modalTitle.textContent = '✏️ Edit Manual / Friendly Fixture';
            
            document.getElementById('cf-id').value = btn.dataset.id || '';
            document.getElementById('cf-home').value = btn.dataset.home || '';
            document.getElementById('cf-away').value = btn.dataset.away || '';
            document.getElementById('cf-date').value = btn.dataset.dateIso || '';
            document.getElementById('cf-time').value = btn.dataset.time || '15:00';
            document.getElementById('cf-home-score').value = btn.dataset.hs || '';
            document.getElementById('cf-away-score').value = btn.dataset.as || '';
            document.getElementById('cf-venue').value = btn.dataset.venue || 'Friendly Match';

            if (customFixtureModal) customFixtureModal.classList.remove('hidden');
        });
    });

    // Delete Custom Fixture
    document.querySelectorAll('.btn-delete-cf').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = btn.dataset.id;
            if (confirm('Are you sure you want to delete this custom fixture?')) {
                fetch(`/api/fixtures/custom/${id}`, { method: 'DELETE' })
                    .then(r => r.json())
                    .then(res => {
                        if (res.success) {
                            localStorage.setItem('rfu_active_tab', 'fixtures');
                            window.location.hash = 'fixtures';
                            window.location.reload();
                        } else {
                            alert(res.error || 'Failed to delete fixture.');
                        }
                    })
                    .catch(err => console.error(err));
            }
        });
    });

    // Logo Management JS Handlers
    const openLogoModalBtn = document.getElementById('open-logo-modal-btn');
    const customLogoModal = document.getElementById('custom-logo-modal');
    const customLogoForm = document.getElementById('custom-logo-form');
    const customLogosList = document.getElementById('custom-logos-list');

    function loadCustomLogosList() {
        if (!customLogosList) return;
        customLogosList.innerHTML = '<p style="font-size: 0.85rem; color: var(--text-muted);">Loading logos...</p>';
        
        fetch('/api/admin/logos')
            .then(r => r.json())
            .then(data => {
                const logos = data.logos || {};
                const keys = Object.keys(logos);
                if (keys.length === 0) {
                    customLogosList.innerHTML = '<p style="font-size: 0.85rem; color: var(--text-muted); font-style: italic;">No custom logos uploaded yet.</p>';
                    return;
                }
                let html = '';
                keys.forEach(k => {
                    const filename = logos[k];
                    html += `
                        <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.5rem 0.75rem; background: rgba(255,255,255,0.05); border-radius: 6px; border: 1px solid var(--bg-card-border);">
                            <div style="display: flex; align-items: center; gap: 0.75rem;">
                                <img src="/api/logos/${filename}" alt="" style="width: 28px; height: 28px; object-fit: contain; border-radius: 4px;">
                                <span style="font-size: 0.85rem; font-weight: 600; text-transform: capitalize;">${k}</span>
                            </div>
                            <button type="button" class="btn-delete-logo" data-team="${k}" style="background: rgba(244, 63, 94, 0.2); color: var(--accent-rose); border: 1px solid rgba(244, 63, 94, 0.4); padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.75rem; cursor: pointer;">🗑️ Delete</button>
                        </div>
                    `;
                });
                customLogosList.innerHTML = html;

                // Bind delete listeners
                customLogosList.querySelectorAll('.btn-delete-logo').forEach(btn => {
                    btn.addEventListener('click', () => {
                        const teamName = btn.dataset.team;
                        if (confirm(`Delete custom logo for ${teamName}?`)) {
                            fetch(`/api/admin/logos/${encodeURIComponent(teamName)}`, { method: 'DELETE' })
                                .then(r => r.json())
                                .then(res => {
                                    if (res.success) {
                                        loadCustomLogosList();
                                    } else {
                                        alert(res.error || 'Failed to delete logo.');
                                    }
                                });
                        }
                    });
                });
            })
            .catch(err => {
                customLogosList.innerHTML = '<p style="font-size: 0.85rem; color: var(--accent-rose);">Failed to load logos.</p>';
            });
    }

    if (openLogoModalBtn && customLogoModal) {
        openLogoModalBtn.addEventListener('click', () => {
            customLogoModal.classList.remove('hidden');
            loadCustomLogosList();
        });
    }

    if (customLogoForm) {
        customLogoForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const teamName = document.getElementById('logo-team-name').value.trim();
            const fileInput = document.getElementById('logo-file-input');
            if (!teamName || !fileInput.files.length) {
                alert('Please enter a team name and select an image file.');
                return;
            }

            const formData = new FormData();
            formData.append('team_name', teamName);
            formData.append('file', fileInput.files[0]);

            fetch('/api/admin/logos/upload', {
                method: 'POST',
                body: formData
            })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    alert(`Logo uploaded successfully for ${res.team_name}!`);
                    document.getElementById('logo-team-name').value = '';
                    fileInput.value = '';
                    loadCustomLogosList();
                } else {
                    alert(res.error || 'Failed to upload logo.');
                }
            })
            .catch(err => {
                console.error(err);
                alert('Error uploading logo file.');
            });
        });
    }
});
