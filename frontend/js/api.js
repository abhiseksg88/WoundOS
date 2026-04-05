/**
 * CarePlix WoundOS – API client
 * Thin wrapper around fetch() that targets the local FastAPI server.
 */

const BASE = "";  // same origin when served via FastAPI static mount

const api = {
  async get(path) {
    const res = await fetch(BASE + path);
    if (!res.ok) throw await res.json();
    return res.json();
  },
  async post(path, body) {
    const res = await fetch(BASE + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw await res.json();
    return res.json();
  },
  async postForm(path, formData) {
    const res = await fetch(BASE + path, {
      method: "POST",
      body: formData,
    });
    if (!res.ok) throw await res.json();
    return res.json();
  },
  async put(path, body) {
    const res = await fetch(BASE + path, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw await res.json();
    return res.json();
  },
  async del(path) {
    const res = await fetch(BASE + path, { method: "DELETE" });
    if (!res.ok && res.status !== 204) throw await res.json();
    return res.status;
  },
};
