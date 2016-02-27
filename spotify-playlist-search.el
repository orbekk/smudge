;; spotify-playlist-search.el --- Spotify.el playlist search major mode

;; Copyright (C) 2014-2016 Daniel Fernandes Martins

;; Code:

(require 'spotify-api)

(defvar spotify-playlist-search-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET")   'spotify-playlist-select)
    (define-key map (kbd "M-RET") 'spotify-playlist-tracks)
    (define-key map (kbd "l")     'spotify-playlist-load-more)
    (define-key map (kbd "L")     'spotify-playlist-reload)
    (define-key map (kbd "f")     'spotify-playlist-follow)
    (define-key map (kbd "u")     'spotify-playlist-unfollow)
    map)
  "Local keymap for `spotify-playlist-search-mode' buffers.")

;; Enables the `spotify-remote-mode' the track search buffer
(add-hook 'spotify-playlist-search-mode-hook 'spotify-remote-mode)

(define-derived-mode spotify-playlist-search-mode tabulated-list-mode "Playlist-Search"
  "Major mode for displaying the playlists returned by a Spotify search.")

(defun spotify-playlist-select ()
  "Plays the playlist under the cursor."
  (interactive)
  (let ((selected-playlist (tabulated-list-get-id)))
    (spotify-play-track selected-playlist)))

(defun spotify-playlist-reload ()
  "Reloads the first page of results for the current playlist view."
  (interactive)
  (if (bound-and-true-p spotify-query)
      (spotify-playlist-search-update 1)
    (spotify-my-playlists-update 1)))

(defun spotify-playlist-load-more ()
  "Loads the next page of results for the current playlist view."
  (interactive)
  (if (bound-and-true-p spotify-query)
      (spotify-playlist-search-update (1+ spotify-current-page))
    (spotify-my-playlists-update (1+ spotify-current-page))))

(defun spotify-playlist-follow ()
  "Adds the current user as the follower of the playlist under the cursor."
  (interactive)
  (let* ((selected-playlist (tabulated-list-get-id))
         (name (spotify-get-item-name selected-playlist)))
    (when (and (y-or-n-p (format "Follow playlist '%s'?" name))
               (spotify-api-playlist-follow selected-playlist))
      (message (format "Followed playlist '%s'" name)))))

(defun spotify-playlist-unfollow ()
  "Removes the current user as the follower of the playlist under the cursor."
  (interactive)
  (let* ((selected-playlist (tabulated-list-get-id))
         (name (spotify-get-item-name selected-playlist)))
    (when (and (y-or-n-p (format "Unfollow playlist '%s'?" name))
               (spotify-api-playlist-unfollow selected-playlist))
      (message (format "Unfollow playlist '%s'" name)))))

(defun spotify-playlist-search-update (current-page)
  "Fetches the given page of results using the search endpoint."
  (let* ((json (spotify-api-search 'playlist spotify-query current-page))
         (items (spotify-get-search-playlist-items json)))
    (if items
        (progn
          (spotify-playlist-search-print items current-page)
          (setq-local spotify-current-page current-page)
          (message "playlist view updated"))
      (message "No more playlists"))))

(defun spotify-my-playlists-update (current-page)
  "Fetches the given page of results using the user's playlist endpoint."
  (let* ((json (spotify-api-user-playlists (spotify-current-user-id) current-page))
         (items (spotify-get-items json)))
    (if items
        (progn
          (spotify-playlist-search-print items current-page)
          (setq-local spotify-current-page current-page)
          (message "Playlist view updated"))
      (message "No more playlists"))))

(defun spotify-playlist-tracks ()
  "Displays the tracks that belongs to the playlist under the cursor."
  (interactive)
  (let* ((selected-playlist (tabulated-list-get-id))
         (name (spotify-get-item-name selected-playlist)))
    (let ((buffer (get-buffer-create (format "*Playlist Tracks: %s*" name))))
      (with-current-buffer buffer
        (spotify-track-search-mode)
        (spotify-track-search-set-list-format)
        (setq-local spotify-selected-playlist selected-playlist)
        (spotify-playlist-tracks-update 1)
        (pop-to-buffer buffer)
        buffer))))

(defun spotify-playlist-set-list-format ()
  "Configures the column data for the typical playlist view."
  (setq tabulated-list-format
        (vector `("Playlist Name" ,(- (window-width) 45) t)
                '("Owner Id" 30 t)
                '("# Tracks" 8 nil :right-align t))))

(defun spotify-playlist-search-print (playlists current-page)
  "Appends the given playlists to the current playlist view."
  (let (entries)
    (dolist (playlist playlists)
      (let ((user-id (spotify-get-playlist-owner-id playlist))
            (playlist-name (spotify-get-item-name playlist)))
        (push (list playlist
                    (vector playlist-name
                            user-id
                            (number-to-string (spotify-get-playlist-track-count playlist))))
              entries)))
    (when (eq 1 current-page)
      (setq-local tabulated-list-entries nil))
    (setq tabulated-list-entries (append tabulated-list-entries (nreverse entries)))
    (tabulated-list-init-header)
    (tabulated-list-print t)))

(provide 'spotify-playlist-search)
