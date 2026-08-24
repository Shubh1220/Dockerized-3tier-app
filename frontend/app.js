// All requests go to /api/* which nginx reverse-proxies to the backend container.
const API_BASE = "/api";

const form = document.getElementById("task-form");
const input = document.getElementById("task-input");
const list = document.getElementById("task-list");
const status = document.getElementById("status");

async function loadTasks() {
  status.textContent = "Loading...";
  try {
    const res = await fetch(`${API_BASE}/tasks`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const tasks = await res.json();
    renderTasks(tasks);
    status.textContent = `${tasks.length} task(s)`;
  } catch (err) {
    status.textContent = `Could not reach backend: ${err.message}`;
  }
}

function renderTasks(tasks) {
  list.innerHTML = "";
  for (const t of tasks) {
    const li = document.createElement("li");
    li.className = t.done ? "done" : "";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = !!t.done;
    checkbox.addEventListener("change", () => toggleTask(t.id, checkbox.checked));

    const span = document.createElement("span");
    span.textContent = t.title;

    const del = document.createElement("button");
    del.textContent = "x";
    del.addEventListener("click", () => deleteTask(t.id));

    li.append(checkbox, span, del);
    list.appendChild(li);
  }
}

async function toggleTask(id, done) {
  await fetch(`${API_BASE}/tasks/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ done }),
  });
  loadTasks();
}

async function deleteTask(id) {
  await fetch(`${API_BASE}/tasks/${id}`, { method: "DELETE" });
  loadTasks();
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const title = input.value.trim();
  if (!title) return;
  await fetch(`${API_BASE}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title }),
  });
  input.value = "";
  loadTasks();
});

loadTasks();
