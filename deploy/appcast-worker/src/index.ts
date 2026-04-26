export default {
  async fetch(request: Request, env: { ASSETS: Fetcher }): Promise<Response> {
    const url = new URL(request.url)

    if (!url.pathname.startsWith("/stickies-improved")) {
      return new Response("Not found", { status: 404 })
    }

    const assetPath =
      url.pathname === "/stickies-improved" || url.pathname === "/stickies-improved/"
        ? "/appcast.xml"
        : url.pathname.slice("/stickies-improved".length)

    const assetURL = new URL(request.url)
    assetURL.pathname = assetPath
    return env.ASSETS.fetch(assetURL)
  },
}

