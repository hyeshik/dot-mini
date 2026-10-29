import Foundation

/// Deliberately narrow, best-effort DOM access. No message text, values, HTML,
/// selection contents, credentials, or page data leave the web view.
enum ComposerFocusScript {
    static func permits(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        return ["chatgpt.com", "www.chatgpt.com"].contains(url.host?.lowercased() ?? "")
    }

    static let source = #"""
    (() => {
        try {
            if (window !== window.top || location.protocol !== 'https:' ||
                !['chatgpt.com', 'www.chatgpt.com'].includes(location.hostname) ||
                (location.port && location.port !== '443')) return 'unavailable';

            const visible = element => {
                if (element.closest('[hidden], [inert], [aria-hidden="true"]')) return false;
                for (let node = element; node; node = node.parentElement) {
                    const style = getComputedStyle(node);
                    if (style.display === 'none' || style.visibility !== 'visible' ||
                        Number(style.opacity) === 0 || style.contentVisibility === 'hidden') return false;
                }
                const rect = element.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.right > 0 &&
                    rect.top < innerHeight && rect.left < innerWidth;
            };

            // Never move focus out of an in-page modal, including while the
            // composer is still being mounted behind it.
            if ([...document.querySelectorAll('dialog[open], [role="dialog"][aria-modal="true"]')]
                .some(visible)) return 'unavailable';

            // Known composer identifiers only. A future layout without these
            // identifiers quietly opts out; generic search/login fields do not match.
            const candidates = [...document.querySelectorAll('#prompt-textarea, textarea[name="prompt-textarea"]')];
            if (candidates.length === 0) return 'missing';
            const usable = candidates.filter(element => {
                if (!(element instanceof HTMLTextAreaElement || element.isContentEditable) ||
                    element.disabled || element.readOnly || element.getAttribute('aria-disabled') === 'true' ||
                    element.getAttribute('aria-readonly') === 'true' || !visible(element)) return false;
                const rect = element.getBoundingClientRect();
                const x = (Math.max(0, rect.left) + Math.min(innerWidth, rect.right)) / 2;
                const y = (Math.max(0, rect.top) + Math.min(innerHeight, rect.bottom)) / 2;
                const hit = document.elementFromPoint(x, y);
                return hit === element || element.contains(hit);
            });
            if (usable.length !== 1) return 'unavailable';
            const composer = usable[0];
            composer.focus({ preventScroll: true });
            return document.activeElement === composer ? 'focused' : 'unavailable';
        } catch (_) {
            return 'unavailable';
        }
    })()
    """#
}
