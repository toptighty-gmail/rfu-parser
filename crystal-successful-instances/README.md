# Successful Crystal Report Instances JSP

This small Java web application displays counts of successful scheduled Crystal Report instances, grouped by report name and repository folder path. It queries the CMS through the SAP BusinessObjects Java SDK; it does not connect to or query the CMS database directly.

## Deploy

1. Use a Java web application server supported by the installed Crystal Server 2020 support package. The Crystal Server installer bundles Tomcat and SAP documents WDeploy for deploying web applications to a supported external application server.
2. Copy the matching Crystal Server Java SDK JARs and their required dependencies from that server's installation into `WEB-INF/lib`. Use JARs from the same Crystal Server 2020 installation and support package. The exact dependency set can vary; consult the installation's Java SDK deployment guide rather than mixing SDK versions.
3. Deploy this directory as the `crystal-successful-instances` web application on Tomcat (or package it as a WAR with the same contents). Open `/crystal-successful-instances/` in a browser.
4. Sign in with a CMS account that has view access to the repository objects. The CMS host field normally uses `host:6400`. Use HTTPS for the web app so credentials are protected in transit.

The page stores the SDK session in the HTTP session, logs it off when Disconnect is used, and expires the session after 20 minutes. It does not persist the password. Restrict access to this page using your web server's authentication or network access controls.

## What it counts

The InfoStore query filters for `SI_KIND='CrystalReport'`, `SI_INSTANCE=1`, and `SI_SCHEDULE_STATUS=1` (Success). It groups returned instances by parent report, resolves the report's folder path from CMS objects, and shows a count. This is the current set of successful instances retained in the CMS history; it is not a count of all historical runs after history cleanup.

SAP documents the supported InfoStore query mechanism in the [Java SDK Developer Guide](https://help.sap.com/docs/SAP_BUSINESSOBJECTS_BUSINESS_INTELLIGENCE_PLATFORM/0225aa3e7b4b4b17b2d4a882e6f2de96/45a597f86e041014910aba7db0e91070.html) and Crystal Server's Tomcat/WDeploy deployment choices in the [Crystal Server 2020 installation guide](https://help.sap.com/doc/bd56cd8c69994fbb95d61beed7c7d2da/2020/en-US/crs2020_install_win_en.pdf).
