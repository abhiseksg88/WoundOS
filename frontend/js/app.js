/**
 * CarePlix WoundOS – Application logic
 */

/* ─── Utility ────────────────────────────────────────────────────────────── */

function showToast(msg, type = "default") {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.className = `toast ${type} show`;
  clearTimeout(el._timer);
  el._timer = setTimeout(() => { el.classList.remove("show"); }, 3500);
}

function fmtDate(iso) {
  if (!iso) return "–";
  return new Date(iso).toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
}

function healingBadge(status) {
  if (!status) return '<span class="badge badge-default">Unknown</span>';
  const map = { improving: "improving", stable: "stable", deteriorating: "deteriorating", healed: "healed" };
  return `<span class="badge badge-${map[status] || "default"}">${status}</span>`;
}

function fmtEnum(v) {
  if (!v) return "–";
  return v.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
}

/* ─── State ──────────────────────────────────────────────────────────────── */

let allPatients = [];
let allWounds   = [];

/* ─── Navigation ─────────────────────────────────────────────────────────── */

document.querySelectorAll(".nav-btn").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
    document.querySelectorAll(".section").forEach(s => s.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById(btn.dataset.section).classList.add("active");
    if (btn.dataset.section === "dashboard") loadDashboard();
    if (btn.dataset.section === "patients")  loadPatients();
    if (btn.dataset.section === "wounds")    loadWounds();
    if (btn.dataset.section === "assessments") loadAssessments();
  });
});

/* ─── Dashboard ──────────────────────────────────────────────────────────── */

async function loadDashboard() {
  try {
    const [patients, wounds, assessments] = await Promise.all([
      api.get("/patients/"),
      api.get("/wounds/"),
      api.get("/assessments/"),
    ]);
    allPatients = patients;
    allWounds   = wounds;
    document.getElementById("stat-patients").textContent    = patients.length;
    document.getElementById("stat-wounds").textContent      = wounds.length;
    document.getElementById("stat-assessments").textContent = assessments.length;

    const tbody = document.getElementById("recent-patients-body");
    tbody.innerHTML = patients.slice(0, 8).map(p => `
      <tr>
        <td>${p.mrn || "–"}</td>
        <td>${p.first_name} ${p.last_name}</td>
        <td>${fmtDate(p.date_of_birth)}</td>
        <td>${fmtEnum(p.gender)}</td>
        <td><div class="actions">
          <button class="btn btn-sm btn-info" onclick="viewPatient(${p.id})">View</button>
        </div></td>
      </tr>`).join("");
  } catch (e) {
    showToast("Failed to load dashboard", "error");
  }
}

function viewPatient(id) {
  document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
  document.querySelector('[data-section="patients"]').classList.add("active");
  document.querySelectorAll(".section").forEach(s => s.classList.remove("active"));
  document.getElementById("patients").classList.add("active");
  loadPatients();
}

/* ─── Patients ───────────────────────────────────────────────────────────── */

async function loadPatients() {
  try {
    allPatients = await api.get("/patients/");
    renderPatients(allPatients);
  } catch (e) {
    showToast("Failed to load patients", "error");
  }
}

function renderPatients(list) {
  const tbody = document.getElementById("patients-body");
  tbody.innerHTML = list.map(p => `
    <tr>
      <td>${p.mrn || "–"}</td>
      <td>${p.first_name} ${p.last_name}</td>
      <td>${fmtDate(p.date_of_birth)}</td>
      <td>${fmtEnum(p.gender)}</td>
      <td><div class="actions">
        <button class="btn btn-sm btn-info" onclick="editPatient(${p.id})">Edit</button>
        <button class="btn btn-danger btn-sm" onclick="deletePatient(${p.id})">Delete</button>
      </div></td>
    </tr>`).join("") || '<tr><td colspan="5" style="text-align:center;color:var(--muted)">No patients found</td></tr>';
}

document.getElementById("patient-search").addEventListener("input", e => {
  const q = e.target.value.toLowerCase();
  renderPatients(allPatients.filter(p =>
    `${p.first_name} ${p.last_name}`.toLowerCase().includes(q) ||
    (p.mrn && p.mrn.toLowerCase().includes(q))
  ));
});

document.getElementById("btn-new-patient").addEventListener("click", () => {
  clearPatientForm();
  document.getElementById("patient-form-title").textContent = "Register Patient";
  document.getElementById("patient-form-card").style.display = "block";
});

document.getElementById("btn-cancel-patient").addEventListener("click", () => {
  document.getElementById("patient-form-card").style.display = "none";
});

function clearPatientForm() {
  ["patient-id","p-first-name","p-last-name","p-dob","p-mrn","p-phone","p-email",
   "p-address","p-medical-history","p-allergies"].forEach(id => {
    document.getElementById(id).value = "";
  });
  document.getElementById("p-gender").value = "";
}

async function editPatient(id) {
  try {
    const p = await api.get(`/patients/${id}`);
    document.getElementById("patient-id").value = p.id;
    document.getElementById("p-first-name").value = p.first_name;
    document.getElementById("p-last-name").value = p.last_name;
    document.getElementById("p-dob").value = p.date_of_birth;
    document.getElementById("p-gender").value = p.gender;
    document.getElementById("p-mrn").value = p.mrn || "";
    document.getElementById("p-phone").value = p.phone || "";
    document.getElementById("p-email").value = p.email || "";
    document.getElementById("p-address").value = p.address || "";
    document.getElementById("p-medical-history").value = p.medical_history || "";
    document.getElementById("p-allergies").value = p.allergies || "";
    document.getElementById("patient-form-title").textContent = "Edit Patient";
    document.getElementById("patient-form-card").style.display = "block";
    window.scrollTo({ top: 0, behavior: "smooth" });
  } catch (e) {
    showToast("Could not load patient", "error");
  }
}

document.getElementById("patient-form").addEventListener("submit", async e => {
  e.preventDefault();
  const id = document.getElementById("patient-id").value;
  const payload = {
    first_name:     document.getElementById("p-first-name").value,
    last_name:      document.getElementById("p-last-name").value,
    date_of_birth:  document.getElementById("p-dob").value,
    gender:         document.getElementById("p-gender").value,
    mrn:            document.getElementById("p-mrn").value || null,
    phone:          document.getElementById("p-phone").value || null,
    email:          document.getElementById("p-email").value || null,
    address:        document.getElementById("p-address").value || null,
    medical_history:document.getElementById("p-medical-history").value || null,
    allergies:      document.getElementById("p-allergies").value || null,
  };
  try {
    if (id) {
      await api.put(`/patients/${id}`, payload);
      showToast("Patient updated", "success");
    } else {
      await api.post("/patients/", payload);
      showToast("Patient registered", "success");
    }
    document.getElementById("patient-form-card").style.display = "none";
    loadPatients();
  } catch (err) {
    showToast(err.detail || "Error saving patient", "error");
  }
});

async function deletePatient(id) {
  if (!confirm("Delete this patient and all their wound records?")) return;
  try {
    await api.del(`/patients/${id}`);
    showToast("Patient deleted", "success");
    loadPatients();
  } catch (e) {
    showToast("Could not delete patient", "error");
  }
}

/* ─── Wounds ─────────────────────────────────────────────────────────────── */

async function loadWounds() {
  try {
    [allPatients, allWounds] = await Promise.all([
      api.get("/patients/"),
      api.get("/wounds/"),
    ]);
    populatePatientSelects();
    renderWounds(allWounds);
  } catch (e) {
    showToast("Failed to load wounds", "error");
  }
}

function renderWounds(list) {
  const tbody = document.getElementById("wounds-body");
  const patMap = Object.fromEntries(allPatients.map(p => [p.id, p]));
  tbody.innerHTML = list.map(w => {
    const p = patMap[w.patient_id];
    const pName = p ? `${p.first_name} ${p.last_name}` : "–";
    return `<tr>
      <td>${pName}</td>
      <td>${fmtEnum(w.wound_type)}</td>
      <td>${w.location}</td>
      <td>${fmtEnum(w.stage)}</td>
      <td>${fmtDate(w.created_at)}</td>
      <td><div class="actions">
        <button class="btn btn-danger btn-sm" onclick="deleteWound(${w.id})">Delete</button>
      </div></td>
    </tr>`;
  }).join("") || '<tr><td colspan="6" style="text-align:center;color:var(--muted)">No wounds recorded</td></tr>';
}

function populatePatientSelects() {
  const sel = document.getElementById("w-patient");
  sel.innerHTML = '<option value="">Select patient…</option>' +
    allPatients.map(p => `<option value="${p.id}">${p.first_name} ${p.last_name} (${p.mrn || "No MRN"})</option>`).join("");
}

document.getElementById("btn-new-wound").addEventListener("click", () => {
  document.getElementById("wound-form").reset();
  populatePatientSelects();
  document.getElementById("wound-form-card").style.display = "block";
});
document.getElementById("btn-cancel-wound").addEventListener("click", () => {
  document.getElementById("wound-form-card").style.display = "none";
});

document.getElementById("wound-form").addEventListener("submit", async e => {
  e.preventDefault();
  const payload = {
    patient_id:  parseInt(document.getElementById("w-patient").value),
    wound_type:  document.getElementById("w-type").value,
    location:    document.getElementById("w-location").value,
    stage:       document.getElementById("w-stage").value || null,
    description: document.getElementById("w-description").value || null,
  };
  try {
    await api.post("/wounds/", payload);
    showToast("Wound recorded", "success");
    document.getElementById("wound-form-card").style.display = "none";
    loadWounds();
  } catch (err) {
    showToast(err.detail || "Error saving wound", "error");
  }
});

async function deleteWound(id) {
  if (!confirm("Delete this wound and all its assessments?")) return;
  try {
    await api.del(`/wounds/${id}`);
    showToast("Wound deleted", "success");
    loadWounds();
  } catch (e) {
    showToast("Could not delete wound", "error");
  }
}

/* ─── Assessments ────────────────────────────────────────────────────────── */

async function loadAssessments() {
  try {
    [allPatients, allWounds] = await Promise.all([
      api.get("/patients/"),
      api.get("/wounds/"),
    ]);
    populateWoundSelects();
    const assessments = await api.get("/assessments/");
    renderAssessments(assessments);
  } catch (e) {
    showToast("Failed to load assessments", "error");
  }
}

function populateWoundSelects() {
  const sel = document.getElementById("a-wound");
  const patMap = Object.fromEntries(allPatients.map(p => [p.id, p]));
  sel.innerHTML = '<option value="">Select wound…</option>' +
    allWounds.map(w => {
      const p = patMap[w.patient_id];
      const pName = p ? `${p.first_name} ${p.last_name}` : "Unknown";
      return `<option value="${w.id}">${pName} – ${fmtEnum(w.wound_type)} (${w.location})</option>`;
    }).join("");
}

function renderAssessments(list) {
  const woundMap = Object.fromEntries(allWounds.map(w => [w.id, w]));
  const tbody = document.getElementById("assessments-body");
  tbody.innerHTML = list.map(a => {
    const w = woundMap[a.wound_id];
    const wDesc = w ? `${fmtEnum(w.wound_type)} – ${w.location}` : "–";
    return `<tr>
      <td>${fmtDate(a.assessment_date)}</td>
      <td>${wDesc}</td>
      <td>${a.assessed_by}</td>
      <td>${a.area_cm2 != null ? a.area_cm2.toFixed(2) : "–"}</td>
      <td>${healingBadge(a.healing_status)}</td>
      <td><div class="actions">
        <button class="btn btn-sm btn-info" onclick="viewReport(${a.wound_id})">Report</button>
        <button class="btn btn-danger btn-sm" onclick="deleteAssessment(${a.id})">Delete</button>
      </div></td>
    </tr>`;
  }).join("") || '<tr><td colspan="6" style="text-align:center;color:var(--muted)">No assessments recorded</td></tr>';
}

document.getElementById("btn-new-assessment").addEventListener("click", () => {
  document.getElementById("assessment-form").reset();
  populateWoundSelects();
  document.getElementById("assessment-form-card").style.display = "block";
  document.getElementById("report-card").style.display = "none";
});
document.getElementById("btn-cancel-assessment").addEventListener("click", () => {
  document.getElementById("assessment-form-card").style.display = "none";
});

document.getElementById("assessment-form").addEventListener("submit", async e => {
  e.preventDefault();
  const formData = new FormData();
  const fields = {
    wound_id:       document.getElementById("a-wound").value,
    assessed_by:    document.getElementById("a-clinician").value,
    length_cm:      document.getElementById("a-length").value,
    width_cm:       document.getElementById("a-width").value,
    depth_cm:       document.getElementById("a-depth").value,
    area_cm2:       document.getElementById("a-area").value,
    wound_bed:      document.getElementById("a-wound-bed").value,
    exudate_amount: document.getElementById("a-exudate-amount").value,
    exudate_type:   document.getElementById("a-exudate-type").value,
    wound_edges:    document.getElementById("a-wound-edges").value,
    periwound_skin: document.getElementById("a-periwound").value,
    odor:           document.getElementById("a-odor").value,
    pain_score:     document.getElementById("a-pain").value,
    healing_status: document.getElementById("a-healing-status").value,
    notes:          document.getElementById("a-notes").value,
    treatment_plan: document.getElementById("a-treatment-plan").value,
  };
  for (const [k, v] of Object.entries(fields)) {
    if (v !== "" && v !== null && v !== undefined) formData.append(k, v);
  }
  const imageFile = document.getElementById("a-image").files[0];
  if (imageFile) formData.append("image", imageFile);

  try {
    await api.postForm("/assessments/with-image", formData);
    showToast("Assessment saved", "success");
    document.getElementById("assessment-form-card").style.display = "none";
    loadAssessments();
  } catch (err) {
    showToast(err.detail || "Error saving assessment", "error");
  }
});

async function viewReport(woundId) {
  try {
    const report = await api.get(`/reports/wound-progress/${woundId}`);
    const rc = document.getElementById("report-content");
    const areaChgClass = report.area_change_pct > 0 ? "positive" : "negative";
    rc.innerHTML = `
      <div class="report-grid">
        <div class="report-stat">
          <div class="value">${report.total_assessments}</div>
          <div class="label">Total Assessments</div>
        </div>
        <div class="report-stat">
          <div class="value">${report.initial_area_cm2 != null ? report.initial_area_cm2.toFixed(2) : "–"}</div>
          <div class="label">Initial Area (cm²)</div>
        </div>
        <div class="report-stat">
          <div class="value">${report.latest_area_cm2 != null ? report.latest_area_cm2.toFixed(2) : "–"}</div>
          <div class="label">Latest Area (cm²)</div>
        </div>
        <div class="report-stat">
          <div class="value ${report.area_change_pct != null ? areaChgClass : ""}">
            ${report.area_change_pct != null ? (report.area_change_pct > 0 ? "+" : "") + report.area_change_pct + "%" : "–"}
          </div>
          <div class="label">Area Change</div>
        </div>
        <div class="report-stat">
          <div class="value">${healingBadge(report.latest_healing_status)}</div>
          <div class="label">Latest Status</div>
        </div>
      </div>
      <p><strong>Wound Type:</strong> ${fmtEnum(report.wound_type)} &nbsp;|&nbsp;
         <strong>Location:</strong> ${report.location}</p>`;
    document.getElementById("report-card").style.display = "block";
    document.getElementById("report-card").scrollIntoView({ behavior: "smooth" });
  } catch (e) {
    showToast("Could not load report", "error");
  }
}

async function deleteAssessment(id) {
  if (!confirm("Delete this assessment?")) return;
  try {
    await api.del(`/assessments/${id}`);
    showToast("Assessment deleted", "success");
    loadAssessments();
  } catch (e) {
    showToast("Could not delete assessment", "error");
  }
}

/* ─── Bootstrap ──────────────────────────────────────────────────────────── */
loadDashboard();
