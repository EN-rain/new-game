using UnityEngine;

public class PlayerLocomotion : MonoBehaviour
{
    InputsManager inputManager;
    Animator animator;
    CameraManager cameraManager;

    Vector3 moveDirection;

    Rigidbody playerRigidbody;

    public float walkingSpeed = 3;
    public float sprintingSpeed = 7;
    public float rotationSpeed = 15;

    private void Awake()
    {
        inputManager = GetComponent<InputsManager>();
        playerRigidbody = GetComponent<Rigidbody>();
        animator = GetComponentInChildren<Animator>();
        cameraManager = Object.FindAnyObjectByType<CameraManager>();
    }

    private void HandleMovement()
    {
        // Move relative to the camera's yaw direction
        Transform cam = cameraManager != null ? cameraManager.transform : null;

        Vector3 forward = cam != null ? cam.forward : Vector3.forward;
        Vector3 right   = cam != null ? cam.right   : Vector3.right;
        forward.y = 0f; forward.Normalize();
        right.y   = 0f; right.Normalize();

        moveDirection  = forward * inputManager.verticalInput;
        moveDirection += right   * inputManager.horizontalInput;
        moveDirection.Normalize();

        float speed = inputManager.sprintInput ? sprintingSpeed : walkingSpeed;
        moveDirection *= speed;

        Vector3 movementVelocity = moveDirection;
        movementVelocity.y = playerRigidbody.velocity.y;
        playerRigidbody.velocity = movementVelocity;

        if (animator != null)
        {
            float inputMagnitude = new Vector2(inputManager.horizontalInput, inputManager.verticalInput).magnitude;
            animator.SetFloat("Speed", inputMagnitude, 0.1f, Time.deltaTime);
        }
    }

    private void HandleRotation()
    {
        Transform cam = cameraManager != null ? cameraManager.transform : null;

        Vector3 forward = cam != null ? cam.forward : Vector3.forward;
        Vector3 right   = cam != null ? cam.right   : Vector3.right;
        forward.y = 0f; forward.Normalize();
        right.y   = 0f; right.Normalize();

        Vector3 targetDirection  = forward * inputManager.verticalInput;
        targetDirection += right * inputManager.horizontalInput;
        targetDirection.Normalize();
        targetDirection.y = 0;

        if (targetDirection == Vector3.zero)
            targetDirection = transform.forward;

        Quaternion targetRotation = Quaternion.LookRotation(targetDirection);
        transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, rotationSpeed * Time.deltaTime);
    }

    public void HandleAllMovement()
    {
        HandleMovement();
        HandleRotation();
    }
}
