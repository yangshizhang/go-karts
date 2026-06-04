using UnityEngine;
using UnityEngine.InputSystem;

namespace GoKartsPico
{
    public sealed class PicoTrackInputController : MonoBehaviour
    {
        [Header("Actions")]
        [SerializeField] private InputActionProperty nextTrackAction;
        [SerializeField] private InputActionProperty previousTrackAction;
        [SerializeField] private InputActionProperty recenterAction;

        [Header("References")]
        [SerializeField] private PicoTrackStore trackStore;
        [SerializeField] private PicoRacingLineRenderer lineRenderer;
        [SerializeField] private Transform lineRoot;
        [SerializeField] private Transform headTransform;

        private int selectedIndex;

        private void Awake()
        {
            if (trackStore == null) trackStore = FindObjectOfType<PicoTrackStore>();
            if (lineRenderer == null) lineRenderer = FindObjectOfType<PicoRacingLineRenderer>();
            if (headTransform == null && Camera.main != null) headTransform = Camera.main.transform;
        }

        private void OnEnable()
        {
            Enable(nextTrackAction, SelectNext);
            Enable(previousTrackAction, SelectPrevious);
            Enable(recenterAction, RecenterLineRoot);
        }

        private void OnDisable()
        {
            Disable(nextTrackAction, SelectNext);
            Disable(previousTrackAction, SelectPrevious);
            Disable(recenterAction, RecenterLineRoot);
        }

        public void SelectNext(InputAction.CallbackContext context)
        {
            if (!context.performed || trackStore == null || trackStore.Tracks.tracks.Count == 0) return;
            selectedIndex = (selectedIndex + 1) % trackStore.Tracks.tracks.Count;
            LoadSelected();
        }

        public void SelectPrevious(InputAction.CallbackContext context)
        {
            if (!context.performed || trackStore == null || trackStore.Tracks.tracks.Count == 0) return;
            selectedIndex = (selectedIndex - 1 + trackStore.Tracks.tracks.Count) % trackStore.Tracks.tracks.Count;
            LoadSelected();
        }

        public void RecenterLineRoot(InputAction.CallbackContext context)
        {
            if (!context.performed || lineRoot == null || headTransform == null) return;
            var forward = Vector3.ProjectOnPlane(headTransform.forward, Vector3.up).normalized;
            if (forward.sqrMagnitude < 0.01f) forward = Vector3.forward;
            lineRoot.position = headTransform.position + forward * 2f;
            lineRoot.rotation = Quaternion.LookRotation(forward, Vector3.up);
        }

        private void LoadSelected()
        {
            trackStore.LoadTrack(trackStore.Tracks.tracks[selectedIndex]);
            lineRenderer.RenderCurrentTrack();
        }

        private static void Enable(InputActionProperty actionProperty, System.Action<InputAction.CallbackContext> callback)
        {
            var action = actionProperty.action;
            if (action == null) return;
            action.performed += callback;
            action.Enable();
        }

        private static void Disable(InputActionProperty actionProperty, System.Action<InputAction.CallbackContext> callback)
        {
            var action = actionProperty.action;
            if (action == null) return;
            action.performed -= callback;
            action.Disable();
        }
    }
}
