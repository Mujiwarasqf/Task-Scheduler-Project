async function getConfig() {
  const res = await fetch('config.json', { cache: 'no-store' });
  return res.json();
}

async function addTask() {
  const cfg = await getConfig();
  const title = document.getElementById('title').value.trim();
  const due = document.getElementById('due').value;
  const time = document.getElementById('time').value;
  const user = document.getElementById('user').value || 'demo';
  if (!title) { alert('Enter a title'); return; }

  let dueDateTime = due;
  if (due && time) {
    dueDateTime = `${due}T${time}`;
  }

  const resp = await fetch(cfg.apiBaseUrl + '/tasks', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ user_id: user, title, due_date: dueDateTime || undefined })
  });
  if (!resp.ok) { alert('Error adding task'); return; }
  document.getElementById('title').value = '';
  document.getElementById('due').value = '';
  document.getElementById('time').value = '';
  await loadTasks();
}

async function loadTasks() {
  const cfg = await getConfig();
  const user = document.getElementById('user').value || 'demo';
  const list = document.getElementById('tasks');
  list.innerHTML = '<p>Loading...</p>';

  const resp = await fetch(cfg.apiBaseUrl + '/tasks?user_id=' + encodeURIComponent(user));
  if (!resp.ok) { list.innerHTML = '<p>Error loading tasks</p>'; return; }
  const tasks = await resp.json();
  list.innerHTML = tasks.map(t => {
    let dueText = '';
    if (t.due_date) {
      const dueDate = new Date(t.due_date);
      if (t.due_date.includes('T')) {
        dueText = ' • Due: ' + dueDate.toLocaleString('en-GB', { 
          timeZone: 'Europe/London',
          day: '2-digit', month: '2-digit', year: 'numeric',
          hour: '2-digit', minute: '2-digit'
        });
      } else {
        dueText = ' • Due: ' + t.due_date;
      }
    }
    return `
      <div class="task">
        <div>
          <strong>${t.title}</strong> ${t.done ? '✅' : ''}<br>
          <small>ID: ${t.SK}${dueText}</small>
        </div>
        ${t.done ? '' : `<button onclick="completeTask('${t.SK}')">Complete</button>`}
      </div>
    `;
  }).join('') || '<p>No tasks yet.</p>';
}

async function completeTask(taskId) {
  const cfg = await getConfig();
  const user = document.getElementById('user').value || 'demo';
  const url = cfg.apiBaseUrl + '/tasks/' + encodeURIComponent(taskId) + '/complete?user_id=' + encodeURIComponent(user);
  const resp = await fetch(url, { method: 'POST' });
  if (!resp.ok) { alert('Error completing task'); return; }
  await loadTasks();
}

function updateTime() {
  const now = new Date();
  const timeStr = now.toLocaleString('en-GB', {
    timeZone: 'Europe/London',
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
  document.getElementById('current-time').textContent = timeStr;
}

window.addEventListener('load', () => {
  loadTasks();
  updateTime();
  setInterval(updateTime, 1000);
});