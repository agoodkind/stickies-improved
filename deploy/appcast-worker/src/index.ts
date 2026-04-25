export default {
  async fetch(request: Request, env: { ASSETS: Fetcher }): Promise<Response> {
    const url = new URL(request.url)

    if (!url.pathname.startsWith("/plainstickies")) {
      return new Response("Not found", { status: 404 })
    }

    const assetPath =
      url.pathname === "/plainstickies" || url.pathname === "/plainstickies/"
        ? "/appcast.xml"
        : url.pathname.slice("/plainstickies".length)

    const assetURL = new URL(request.url)
    assetURL.pathname = assetPath
    return env.ASSETS.fetch(assetURL)
  },
}

