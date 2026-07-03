using UnityEngine;
using Unity.Netcode;

public class PlayerManager : NetworkBehaviour
{
    InputsManager inputsManager;
    PlayerLocomotion playerLocomotion;
    CameraManager cameraManager;

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        if (IsOwner)
        {
            // Set as local player reference in some global manager if needed
        }
    }

    private void Awake()
    {
        inputsManager = GetComponent<InputsManager>();
        playerLocomotion = GetComponent<PlayerLocomotion>();
        cameraManager = Object.FindAnyObjectByType<CameraManager>();
    }

    private void Update()
    {
        if (!IsOwner) return;
        inputsManager.HandleAllInputs();
    }

    private void FixedUpdate()
    {
        if (!IsOwner) return;
        playerLocomotion.HandleAllMovement();
    }

    private void LateUpdate()
    {
        if (!IsOwner) return;
        if (cameraManager != null)
            cameraManager.HandleAllCameraMovement();
    }
}
