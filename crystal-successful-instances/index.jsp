<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,com.crystaldecisions.sdk.framework.*,com.crystaldecisions.sdk.occa.infostore.*" %>
<%!
  private String esc(Object value) {
    if (value == null) return "";
    return String.valueOf(value).replace("&", "&amp;").replace("<", "&lt;")
      .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
  }
  private String prop(IInfoObject obj, String key) {
    IProperty p = obj.properties().getProperty(key);
    return p == null || p.getValue() == null ? "" : String.valueOf(p.getValue());
  }
  private String idList(Collection<String> ids) {
    StringJoiner j = new StringJoiner(",");
    for (String id : ids) if (id.matches("\\d+")) j.add(id);
    return j.toString();
  }
  private IInfoObjects fetchIds(IInfoStore store, String ids) throws Exception {
    if (ids == null || ids.length() == 0) return null;
    return store.query("SELECT SI_ID, SI_NAME, SI_PARENTID FROM CI_INFOOBJECTS WHERE SI_ID IN (" + ids + ")");
  }
%>
<%
  request.setCharacterEncoding("UTF-8");
  String error = null;
  IEnterpriseSession enterprise = (IEnterpriseSession) session.getAttribute("crystalEnterpriseSession");
  String action = request.getParameter("action");

  if ("logout".equals(action)) {
    if (enterprise != null) try { enterprise.logoff(); } catch (Exception ignored) {}
    session.removeAttribute("crystalEnterpriseSession");
    enterprise = null;
  }

  if ("login".equals(action)) {
    String cms = request.getParameter("cms");
    String username = request.getParameter("username");
    String password = request.getParameter("password");
    String auth = request.getParameter("auth");
    try {
      if (cms == null || cms.trim().isEmpty() || username == null || username.trim().isEmpty())
        throw new Exception("Enter the CMS name or host and your username.");
      enterprise = CrystalEnterprise.getSessionMgr().logon(username, password, cms, auth);
      session.setAttribute("crystalEnterpriseSession", enterprise);
    } catch (Exception ex) {
      error = "Could not sign in to the CMS. Check the CMS, credentials, and authentication type.";
      enterprise = null;
    }
  }

  List<String[]> rows = new ArrayList<String[]>();
  long total = 0;
  if (enterprise != null) {
    try {
      IInfoStore store = (IInfoStore) enterprise.getService("InfoStore");
      IInfoObjects instances = store.query(
        "SELECT SI_ID, SI_NAME, SI_PARENTID FROM CI_INFOOBJECTS " +
        "WHERE SI_KIND='CrystalReport' AND SI_INSTANCE=1 AND SI_SCHEDULE_STATUS=1"
      );

      Map<String,Integer> counts = new HashMap<String,Integer>();
      Set<String> reportIds = new LinkedHashSet<String>();
      for (int i=0; i<instances.size(); i++) {
        IInfoObject instance = (IInfoObject) instances.get(i);
        String reportId = prop(instance, "SI_PARENTID");
        if (reportId.matches("\\d+")) {
          reportIds.add(reportId);
          counts.put(reportId, counts.containsKey(reportId) ? counts.get(reportId)+1 : 1);
        }
      }

      Map<String,String> reportNames = new HashMap<String,String>();
      Map<String,String> reportFolderIds = new HashMap<String,String>();
      IInfoObjects reports = fetchIds(store, idList(reportIds));
      if (reports != null) for (int i=0; i<reports.size(); i++) {
        IInfoObject report = (IInfoObject) reports.get(i);
        String id = prop(report, "SI_ID");
        reportNames.put(id, prop(report, "SI_NAME"));
        reportFolderIds.put(id, prop(report, "SI_PARENTID"));
      }

      Map<String,String> folderNames = new HashMap<String,String>();
      Map<String,String> folderParents = new HashMap<String,String>();
      Set<String> pending = new LinkedHashSet<String>(reportFolderIds.values());
      pending.remove("");
      for (int depth=0; depth<64 && !pending.isEmpty(); depth++) {
        Set<String> unseen = new LinkedHashSet<String>(pending);
        unseen.removeAll(folderNames.keySet());
        if (unseen.isEmpty()) break;
        IInfoObjects folders = fetchIds(store, idList(unseen));
        pending.clear();
        if (folders == null) break;
        for (int i=0; i<folders.size(); i++) {
          IInfoObject folder = (IInfoObject) folders.get(i);
          String id = prop(folder, "SI_ID");
          String parent = prop(folder, "SI_PARENTID");
          folderNames.put(id, prop(folder, "SI_NAME"));
          folderParents.put(id, parent);
          if (parent.matches("\\d+") && !"4".equals(id)) pending.add(parent);
        }
      }

      for (String reportId : counts.keySet()) {
        String folderId = reportFolderIds.get(reportId);
        List<String> path = new ArrayList<String>();
        Set<String> seen = new HashSet<String>();
        while (folderId != null && folderId.matches("\\d+") && !"4".equals(folderId)
               && seen.add(folderId) && folderNames.containsKey(folderId)) {
          path.add(folderNames.get(folderId));
          folderId = folderParents.get(folderId);
        }
        Collections.reverse(path);
        StringBuilder fullPath = new StringBuilder("/");
        for (String part : path) {
          if (fullPath.length() > 1) fullPath.append('/');
          fullPath.append(part);
        }
        rows.add(new String[] { fullPath.toString(), reportNames.containsKey(reportId) ? reportNames.get(reportId) : "(report " + reportId + ")", String.valueOf(counts.get(reportId)) });
        total += counts.get(reportId);
      }
      Collections.sort(rows, new Comparator<String[]>() {
        public int compare(String[] a, String[] b) {
          int c = a[0].compareToIgnoreCase(b[0]);
          return c != 0 ? c : a[1].compareToIgnoreCase(b[1]);
        }
      });
    } catch (Exception ex) {
      error = "The CMS query failed. Check that the application has the matching Crystal Server Java SDK libraries and that the signed-in account can view the repository objects.";
    }
  }
%>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Successful Crystal Report Instances</title>
  <style>
    :root { color-scheme: light; --ink:#172033; --muted:#687386; --line:#e2e7ef; --blue:#2458d3; }
    * { box-sizing:border-box; }
    body { margin:0; background:#f5f7fb; color:var(--ink); font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif; }
    main { width:min(1100px,calc(100% - 32px)); margin:48px auto; }
    h1 { margin:0; font-size:clamp(26px,4vw,36px); letter-spacing:-.03em; }
    .muted { color:var(--muted); }
    .panel { background:#fff; border:1px solid var(--line); border-radius:14px; padding:22px; box-shadow:0 6px 24px #1624470a; }
    .login { max-width:480px; margin:28px auto; }
    label { display:block; font-weight:650; margin:14px 0 5px; }
    input,select { width:100%; border:1px solid #cbd3e0; border-radius:8px; padding:10px 12px; font:inherit; }
    button { border:0; border-radius:8px; padding:10px 15px; color:#fff; background:var(--blue); font-weight:650; cursor:pointer; }
    .login button { width:100%; margin-top:18px; }
    .top { display:flex; justify-content:space-between; align-items:center; gap:16px; flex-wrap:wrap; margin:25px 0 12px; }
    .alert { margin:18px 0; color:#9d3323; background:#fff0ed; border:1px solid #f3ccc3; border-radius:8px; padding:12px 14px; }
    .table-wrap { overflow:auto; border:1px solid var(--line); border-radius:10px; background:white; }
    table { border-collapse:collapse; width:100%; text-align:left; }
    th,td { padding:12px 14px; border-bottom:1px solid var(--line); }
    th { background:#f8f9fc; color:#485368; font-size:12px; text-transform:uppercase; letter-spacing:.045em; }
    tr:last-child td { border-bottom:0; }
    td.count,th.count { text-align:right; font-variant-numeric:tabular-nums; }
    .summary { font-weight:650; }
    @media(max-width:600px) { main { margin:24px auto; } .panel { padding:15px; } }
  </style>
</head>
<body>
<main>
  <h1>Successful Crystal Report Instances</h1>
  <p class="muted">Counts completed successfully in the CMS repository, grouped by report and folder.</p>
  <% if (error != null) { %><div class="alert" role="alert"><%= esc(error) %></div><% } %>
  <% if (enterprise == null) { %>
    <form class="panel login" method="post">
      <input type="hidden" name="action" value="login">
      <h2>Connect to Crystal Server</h2>
      <label for="cms">CMS host and port</label>
      <input id="cms" name="cms" required placeholder="crystal-server:6400" autocomplete="url">
      <label for="username">Username</label>
      <input id="username" name="username" required autocomplete="username">
      <label for="password">Password</label>
      <input id="password" name="password" type="password" autocomplete="current-password">
      <label for="auth">Authentication type</label>
      <select id="auth" name="auth"><option value="secEnterprise">Enterprise</option><option value="secLDAP">LDAP</option><option value="secWinAD">Windows AD</option><option value="secSAPR3">SAP</option></select>
      <button type="submit">Connect and load results</button>
    </form>
  <% } else { %>
    <div class="top">
      <div><div class="summary"><%= rows.size() %> reports · <%= total %> successful instances</div><div class="muted">Status 1 (Success); CrystalReport objects only.</div></div>
      <form method="post"><input type="hidden" name="action" value="logout"><button type="submit">Disconnect</button></form>
    </div>
    <div class="table-wrap"><table>
      <thead><tr><th>Folder path</th><th>Report name</th><th class="count">Successful instances</th></tr></thead>
      <tbody>
      <% if (rows.isEmpty()) { %><tr><td colspan="3" class="muted">No successful Crystal Report instances were found.</td></tr><% } %>
      <% for (String[] row : rows) { %><tr><td><%= esc(row[0]) %></td><td><%= esc(row[1]) %></td><td class="count"><%= esc(row[2]) %></td></tr><% } %>
      </tbody>
    </table></div>
  <% } %>
</main>
</body>
</html>
