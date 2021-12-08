using UnityEngine;

//[ExecuteInEditMode]
[RequireComponent(typeof(Light))]
public class SkyController : MonoBehaviour
{
    [Header("Sky Colors")] public bool overrideSkyColors;
    [GradientUsage(true)] public Gradient topColor;
    [GradientUsage(true)] public Gradient middleColor;
    [GradientUsage(true)] public Gradient bottomColor;

    [Header("Sun color")]
    public bool overrideSunColor;
    [GradientUsage(true)]
    public Gradient sunColor;
 
    [Header("Sun light color")]
    public bool overrideLightColor;
    public Gradient lightColor;
    
    [Header("Ambient sky color")]
    public bool overrideAmbientSkyColor;
    [GradientUsage(true)]
    public Gradient ambientSkyColor;
    
    [Header("Clouds color")]
    public bool overrideCloudsColor;
    [GradientUsage(true)]
    public Gradient cloudsColor;
    
    [Header("Debug scrub")] public bool useScrub;
    [Range(0.0f, 1.0f)] public float scrub;

    private Material _skyMaterial;

    private Light _sun;

    public Light Sun
    {
        get
        {
            if (_sun == null) _sun = GetComponent<Light>();

            return _sun;
        }
    }

    public Material SkyMaterial
    {
        get
        {
            if (_skyMaterial == null) _skyMaterial = RenderSettings.skybox;

            return _skyMaterial;
        }
    }

    private void Update()
    {
        if (!useScrub && Sun.transform.hasChanged)
        {
            var pos = Vector3.Dot(Sun.transform.forward.normalized, Vector3.up) * 0.5f + 0.5f;
            UpdateGradients(pos);
        }

        var sunTransform = Sun.transform;

        Sun.transform.Rotate(sunTransform.right, 0.25f);
    }

    public void OnValidate()
    {
        if (useScrub) UpdateGradients(scrub);
    }

    public void UpdateGradients(float position)
    {
        if (overrideSkyColors)
        {
            SkyMaterial.SetColor("_ColorTop", topColor.Evaluate(position));
            SkyMaterial.SetColor("_ColorMiddle", middleColor.Evaluate(position));
            SkyMaterial.SetColor("_ColorBottom", bottomColor.Evaluate(position));
        }
        if (overrideSunColor) {
            SkyMaterial.SetColor("_SunColor", sunColor.Evaluate(position));
        }
        if (overrideLightColor) {
            Sun.color = lightColor.Evaluate(position);
        }
        if (overrideAmbientSkyColor) {
            if (RenderSettings.ambientMode == UnityEngine.Rendering.AmbientMode.Trilight) {
                RenderSettings.ambientSkyColor = topColor.Evaluate(position);
                RenderSettings.ambientEquatorColor = middleColor.Evaluate(position);
                RenderSettings.ambientGroundColor = bottomColor.Evaluate(position);
            } else if (RenderSettings.ambientMode == UnityEngine.Rendering.AmbientMode.Flat) {
                RenderSettings.ambientSkyColor = ambientSkyColor.Evaluate(position);
            }
        }
        if (overrideCloudsColor) {
            SkyMaterial.SetColor("_CloudsColor", cloudsColor.Evaluate(position));
        }
    }
}